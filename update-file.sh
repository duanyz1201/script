#!/bin/bash

github_release_url="https://api.github.com/repos/zklion-miner/Aleo-miner/releases/latest"
download_path="/usr/share/nginx/html/zklion-miner/"
assets_directory="$download_path/assets"
last_asset_ids_file="$download_path/last_asset_ids.txt"

download_asset() {
    asset_id=$1
    asset_url=$2

    echo "Downloading asset with ID $asset_id..."
    curl -L -o "$download_path" "$asset_url"
}

latest_release=$(curl -s "$github_release_url" | jq '.[0]')

assets=($(echo "$latest_release" | jq -r '.assets[] | "\(.id) \(.browser_download_url)"'))

read -a last_seen_asset_ids < "$last_asset_ids_file"

new_assets=()
for asset in "${assets[@]}"; do
    asset_id=$(echo "$asset" | cut -d ' ' -f 1)
    asset_url=$(echo "$asset" | cut -d ' ' -f 2)

    if ! [[ " ${last_seen_asset_ids[@]} " =~ " $asset_id " ]]; then
        new_assets+=("$asset")
    fi
done

if [ ${#new_assets[@]} -gt 0 ]; then
    for new_asset in "${new_assets[@]}"; do
        asset_id=$(echo "$new_asset" | cut -d ' ' -f 1)
        asset_url=$(echo "$new_asset" | cut -d ' ' -f 2)
        download_asset "$asset_id" "$asset_url"
    done

    echo "${assets[@]}" | cut -d ' ' -f 1 > "$last_asset_ids_file"
else
    echo "No new assets found."
fi

