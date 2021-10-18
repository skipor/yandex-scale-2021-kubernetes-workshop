# Выполните 'source ./set_tf_vars_from_yc_config.sh' перед вызовом terraform

TF_VAR_yc_token=$(yc config get token)
if [[ "$TF_VAR_yc_token" == "" ]]; then
  echo "WARN: There is no 'token' in 'yc config'"
else
  export TF_VAR_yc_token
fi

TF_VAR_folder_id=$(yc config get folder-id)
if [[ "$TF_VAR_folder_id" == "" ]]; then
  echo "WARN: There is no 'folder_id' in 'yc config'"
else
  export TF_VAR_folder_id
fi


