#/bin/bash

log_file="del-expired-sectors.log"

for file_path in $(cat ${1})
do
    if [[ -z ${file_path} || ! -f ${file_path} ]];then
        echo "$(date '+%FT%T.%3N') ${file_path} is not a file!" | tee -a ${log_file}
        continue
    else
        rm ${file_path}
        if [[ $? -eq 0 ]];then
            echo "$(date '+%FT%T.%3N') ${file_path} deleted successfully!" | tee -a ${log_file}
        else
            echo "$(date '+%FT%T.%3N') ${file_path} deletion failed!" | tee -a ${log_file}
        fi
    fi
done