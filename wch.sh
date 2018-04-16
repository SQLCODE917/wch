#!/usr/bin/env bash

# wch - what changed? (pronounced "witch")
# calculate your coin-to-coin crypto investment profits
# based on historical values


# requirements:


# bash 4.3
#   for `-v` operator that can be applied to arrays

#  jq for JSON parsing
#   https://stedolan.github.io/jq/

# GNU coreutils for `date` parsing
#   `--date` and `%s` are GNU extensions
# for debugging


# set -o xtrace
# exit if attempting to use undeclared vars
set -o nounset

# gracefully exit, whether from error or end of file
clean_up(){
    set +o nounset
    set +o xtrace
    cd "${__initial_cwd}"
    return
}
trap clean_up SIGHUP SIGINT SIGTERM ERR

__initial_cwd="$(pwd -P)"
# where this file is in
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

cd "${__dir}"


# feature 1 - given a coin-to-coin trade and it's date,
#   calculate profit 
# in file in the same dir as this script, "wch.json",

#{
#    "initialTrades": [
#        {
#            "coin": "XLM",
#            "exchangedForCoin": "ETH",
#            "when": "2017-12-19 16:37:35",
#            "howMany": 1875
#        },
#        {
#            "coin": "LRC",
#            "exchangedForCoin": "ETH",
#            "when": "2017-12-19 05:37:35",
#            "howMany": 1588
#        }
#    ]
#}

__now_ts="$(date +"%s")"

# associative array to cache current coin prices
declare -A nowPrices=()
# array to cache the profits
#declare -a profits=(0)
profits=()

historicPrice(){
    local fromSymbol=$1
    local toSymbol="USD"
    local timestamp=$2
    
    local response=$(curl -s -X GET -G \
        'https://min-api.cryptocompare.com/data/pricehistorical' \
        -d fsym="${fromSymbol}" \
        -d tsyms="${toSymbol}" \
        -d ts="${timestamp}")
    local price=$(jq ".$fromSymbol .$toSymbol"<<<"$response")
    echo "${price}"
}

cacheNowPrice(){
    local fromSymbol=$1
    local price=$(historicPrice $fromSymbol "${__now_ts}")
    nowPrices[$fromSymbol]="${price}"
}

while read -r coin &&
    read -r exchangedForCoin &&
    read -r when &&
    read -r howMany; do

    [[ "${nowPrices[$coin]-}" ]] || cacheNowPrice $coin
    nowPrice="${nowPrices[$coin]}"
    when_ts="$(date --date="${when}" +%s)"
    boughtForPrice=$(historicPrice $coin $when_ts)

    profitPerCoin=$(echo ${nowPrice#0}-${boughtForPrice#0} | bc -l)
    profit=$(echo ${profitPerCoin#0} \* ${howMany#0} | bc -l)
    
    profits+=${profit#0}

    echo "${coin} is ${nowPrice}, was bought for ${boughtForPrice} on ${when} ($when_ts), profit ${profit}"
done < <(jq -r '.["initialTrades"] | .[] | (.coin, .exchangedForCoin, .when, .howMany)' < wch.json)

$totalProfit=$(IFS="+";bc<<<"${profits[*]}")
# $totalProfit=$(echo "${profits[@]/ /+}" | bc)
echo "Total Profit: ${totalProfit}"

clean_up
