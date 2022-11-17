#!/usr/bin/env bash
set -x 

apply_state () {
    local file="$1"
    local state="$2"
    local delete=0
    local kind version package name

    if [[ -f $file ]]; then
        echo "» Processing $file"
    else
        prev_commit=$(git rev-parse @~)
        git checkout "${prev_commit}" "$file" 
        echo "» Processing $file"
        delete=1
    fi

    if [[ $state == "dump" ]]; then
        exit 0
    fi

    parse_value_for() {
        local key="$1"
        grep -m 1 "${key}:" "$file" | cut -d":" -f2 | awk '{$1=$1;print}'
    }

    parse_mgmt_cluster_from_json_file() {
        local json_file="$1"
        jq '.fullName.managementClusterName' "$json_file" | sed 's/\"//g'
    }

    parse_provisioner_from_json_file() {
        local json_file="$1"
        jq '.fullName.managementClusterName' "$json_file" | sed 's/\"//g'
    }

    type_cluster_group() {
        if [[ delete -eq 1 ]]; then
            echo "» Deleting cluster group $name"
            tmc clustergroup delete "$name"
        else
            if tmc clustergroup get "$name" &> /dev/null; then
                echo "» Updating cluster group $name"
                tmc clustergroup update "$name" -f "$file"
            else
                echo "» Creating cluster group $name"
                tmc clustergroup create -f "$file"
            fi
        fi
    }

    type_cluster() {
        local mgmt_cluster provisioner version
        if [[ delete -eq 1 ]]; then
            echo "» Deleting cluster $name"
            tmc cluster delete "$name"
        else
            if tmc cluster list | grep "$name" &> /dev/null; then
                echo "» Found cluster $name"
                tmc cluster list --name "$name" -o json  |  jq -c '.clusters[0]' > cluster-info.json
                echo "» Retrieve the management cluster and provisioner"
                mgmt_cluster=$(parse_mgmt_cluster_from_json_file cluster-info.json)
                echo "» Management cluster: $mgmt_cluster"
                provisioner=$(parse_provisioner_from_json_file cluster-info.json)
                echo "» Provisioner:$provisioner"
                echo "» Updating cluster $name"
                version=$(jq '.meta.resourceVersion' cluster-info.json | sed 's/\"//g' )
                #sed -e "s/meta:/meta:\\n  resourceVersion: $version/g" ${1} > tmpfile.yaml
                ./cluster_patch_yaml.sh "$file" "$version" tmpfile.yaml
                cat tmpfile.yaml           
                tmc cluster update "$name" -m "$mgmt_cluster" -p "$provisioner" -f tmpfile.yaml -v 9
                rm tmpfile.yaml
                rm cluster-info.json
            else
                echo "» Creating cluster $name"
                tmc cluster create -f "$file"
            fi
        fi
    }

    type_namespace() {
        local cluster_name mgmt_cluster provisioner
        if [[ delete -eq 1 ]]; then
            echo "» Deleting namespace $name"
            tmc cluster namespace delete "$name" --cluster-name "$cluster_name" 
        else
            clusterName=$(grep -m 1 "clusterName:" "$file" | cut -d":" -f2 | awk '{$1=$1;print}')            
            #TODO: manage return code
            echo "» Found cluster $clusterName"

            echo "» Retrieve the management cluster and provisioner"
            tmc cluster list --name "$clusterName" -o json  |  jq -c '.clusters[0]' > cluster-info.json
            mgmt_cluster=$(jq '.fullName.managementClusterName' cluster-info.json | sed 's/\"//g')
            echo "» Management cluster: $mgmt_cluster"
            provisioner=$(jq '.fullName.provisionerName' cluster-info.json | sed 's/\"//g')                
            echo "» Provisioner: $provisioner"

            if tmc cluster namespace get "$name" --cluster-name "$clusterName" -m "$mgmt_cluster" -p "$provisioner" -o json > namespace.json; then         
                echo "» Updating namespace $name"
                tmc cluster namespace update -f "$file" --cluster-name "$clusterName"                
            else
                echo "» Creating namespace $name"
                tmc cluster namespace create -f "$file"
            fi
            rm namespace.json
            rm cluster-info.json
        fi
    }

    type_workspace() {
        if [[ delete -eq 1 ]]; then
            echo "» Deleting workspace $name"
            tmc workspace delete "$name"
        else
            if tmc workspace get "$name" &> /dev/null; then
                echo "» Updating workspace $name"
                tmc workspace update "$name" -f "$file"
            else
                echo "» Creating workspace $name"
                tmc workspace create -f "$file"
            fi
        fi
    }

    type_image_policy() {
        local cluster_name mgmt_cluster provisioner type command parent_name
        type="image-policy"
        if [[ ${package} == "vmware.tanzu.manage.v1alpha.workspace.policy" ]]; then
            command="workspace"
            parent_name=$(grep "workspaceName:" "$file" | cut -d":" -f2 | awk '{$1=$1;print}')
        fi

        if [[ delete -eq 1 ]]; then
            echo "» Deleting image policy $name"
            tmc "$command" "$type" delete "$name" --workspace-name "$parent_name" 
        else
            if tmc "$command" "$type" get "$name" --workspace-name "$parent_name" &> /dev/null; then
                echo "» Updating image policy $name"
                tmc "$command" "$type" update "$name" --workspace-name "$parent_name" -f "$file"
            else
                echo "» Deleting image policy $name"
                tmc "$command" "$type" create -f "$file"
            fi
        fi
    }

    type_network_policy() {
        local cluster_name mgmt_cluster provisioner type command parent_name
        type="network-policy"
        if [[ ${package} == "vmware.tanzu.manage.v1alpha.workspace.policy" ]]; then
            command="workspace"
            parent_name=$(grep "workspaceName:" "$file" | cut -d":" -f2 | awk '{$1=$1;print}')
        fi

        if [[ delete -eq 1 ]]; then
            echo "» Deleting network policy $name"
            tmc "$command" "$type" delete "$name" --workspace-name "$parent_name" 
        else
            if tmc "$command" "$type" get "$name" --workspace-name "$parent_name" &> /dev/null; then
                echo "» Updating network policy $name"
                tmc "$command" "$type" update "$name" --workspace-name "$parent_name" -f "$file"
            else
                echo "» Deleting network policy $name"
                tmc "$command" "$type" create -f "$file"
            fi
        fi
    }

    type_iam_policy() {
        local cluster_name mgmt_cluster provisioner type command parent_name
        if [[ ${package} == "vmware.tanzu.manage.v1alpha.workspace.policy" ]]; then
            command="workspace"
            workspace_name=$(grep "workspaceName:" "$file" | cut -d":" -f2 | awk '{$1=$1;print}')
        fi

        if [[ delete -eq 1 ]]; then
            echo "» Deleting iam policy $name"
            tmc "$command" iam delete "$workspace_name" 
        else
            if tmc "$command" iam get-policy "$workspace_name" &> /dev/null
            then
                echo "» Updating iam policy $name"
                sed -n '/roleBindings/,$p' "$file" > tmpfile.yaml
                tmc ${command} iam update-policy "$workspace_name" -f tmpfile.yaml -v 9
                rm tmpfile.yaml
	        fi
        fi
    }

    kind=$(parse_value_for "kind")
    version=$(parse_value_for "version")
    package=$(parse_value_for "package")
    name=$(parse_value_for "name")
    # echo "${kind}/${version}/${package}/${name}"

    case $kind in
        "ClusterGroup")     type_cluster_group;;
        "Cluster")          type_cluster;;
        "Namespace")        type_namespace;;
        "Workspace")        type_workspace;;
        "ImagePolicy")      type_image_policy;;
        "NetworkPolicy")    type_network_policy;;
        "IAMPolicy")        type_iam_policy;;
        *)                  echo "Unknown kind: $kind";;
    esac
}

dump_files () {
    local file="$1"
    apply_state "$file" dump
}

while read -r line; do apply_state "$line"; done < <(git diff --name-only HEAD HEAD~1 | grep yaml)

#while read -r line; do dump_files "$line"; done < <(git diff --name-only HEAD HEAD~1 | grep yaml)

