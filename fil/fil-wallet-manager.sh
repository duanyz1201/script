#!/usr/bin/env bash

IFS=$'\n'

export_key() {
wallet_list=$(lotus wallet list -i | tail -n +2)
export_file="$1"

for wl in $wallet_list
do
        ID=$(echo ${wl} | awk '{print $2}')
        Address=$(echo ${wl} | awk '{print $1}')

        for addr in ${Address}
        do
                result=$(lotus wallet export ${addr})
                echo "${ID} ${Address} ${result}" >> ${export_file}
        done
done
}

import_key() {
key_file="$1"

for kf in $(cat ${key_file})
do
        key=$(echo ${kf} |awk '{print $3}')
        echo "${key}" | lotus wallet import
done
}

case "${1}" in
        export_key)
                export_key $2
                ;;
        import_key)
                import_key $2
                ;;
        *)
                echo "Usage: $0 {export_key|import_key}"
                exit 1
                ;;
esac