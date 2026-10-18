#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

export LC_ALL=C

VERBOSE=false
FORCE_REFRESH=false

for arg in "$@"; do
    if [[ "$arg" == "--verbose" || "$arg" == "-v" ]]; then
        VERBOSE=true
    elif [[ "$arg" == "--refresh" || "$arg" == "-r" ]]; then
        FORCE_REFRESH=true
    fi
done

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\e[1;34m[LOCATION-DEBUG]\e[0m $1" >&2
    fi
}

get_existing_location() {
    local gen
    gen="$(get_setting "general" '{}')"
    echo "$gen" | jq -c '.location // empty' 2>/dev/null
}

save_location() {
    local loc_data="$1"
    local gen
    gen="$(get_setting "general" '{}')"
    local updated
    updated="$(echo "$gen" | jq --argjson loc "$loc_data" '.location = $loc')"
    set_setting "general" "$updated"
    "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/weather.sh" --getdata >/dev/null 2>&1 &
}

try_ipapi() {
    log_debug "Attempting primary provider: ipapi.co..."
    local resp
    resp="$(curl -s --max-time 5 -H "User-Agent: serpantinum-location/1.0" "https://ipapi.co/json/" 2>/dev/null)"
    if echo "$resp" | jq -e '(.error | not) and .latitude != null and .longitude != null' >/dev/null 2>&1; then
        echo "$resp" | jq -c '{
            ip: (.ip // null),
            latitude: .latitude,
            longitude: .longitude,
            city: (.city // "Unknown"),
            region: (.region // "Unknown"),
            region_code: (.region_code // null),
            country_name: (.country_name // "Unknown"),
            country_code: (.country_code // null),
            postal: (.postal // null),
            timezone: (.timezone // "UTC"),
            utc_offset: (.utc_offset // null),
            currency: (.currency // null),
            languages: (.languages // null),
            asn: (.asn // null),
            org: (.org // null),
            source: "ipapi.co"
        }'
        return 0
    fi
    return 1
}

try_ipwhois() {
    log_debug "ipapi.co failed or rate-limited. Falling back to ipwho.is..."
    local resp
    resp="$(curl -s --max-time 5 "https://ipwho.is/" 2>/dev/null)"
    if echo "$resp" | jq -e '.success == true and .latitude != null and .longitude != null' >/dev/null 2>&1; then
        echo "$resp" | jq -c '{
            ip: (.ip // null),
            latitude: .latitude,
            longitude: .longitude,
            city: (.city // "Unknown"),
            region: (.region // "Unknown"),
            region_code: (.region_code // null),
            country_name: (.country // "Unknown"),
            country_code: (.country_code // null),
            postal: (.postal // null),
            timezone: (.timezone.id // "UTC"),
            utc_offset: (.timezone.utc // null),
            currency: (.connection.currency // null),
            languages: null,
            asn: ((.connection.asn | tostring) // null),
            org: (.connection.org // null),
            source: "ipwho.is"
        }'
        return 0
    fi
    return 1
}

fetch_ip_location() {
    local res
    if res="$(try_ipapi)" && [[ -n "$res" ]]; then
        echo "$res"
        return 0
    fi
    if res="$(try_ipwhois)" && [[ -n "$res" ]]; then
        echo "$res"
        return 0
    fi
    return 1
}

resolve_location() {
    local existing
    existing="$(get_existing_location)"

    local source
    source="$(echo "$existing" | jq -r '.source // empty' 2>/dev/null)"

    if [[ "$source" == "manual" && "$FORCE_REFRESH" == "false" ]]; then
        echo "$existing"
        return
    fi

    # general.ipGeolocation: false means no automatic lookups: the public IP is
    # only sent to a geolocation service when the user asks for it (--refresh,
    # the "detect" button in Settings > General > Location).
    if [[ "$FORCE_REFRESH" == "false" ]] \
        && [[ "$(get_setting "general" '{}' | jq -r 'if .ipGeolocation == false then "off" else "on" end' 2>/dev/null)" == "off" ]]; then
        log_debug "IP geolocation is off (general.ipGeolocation). Not looking up the location."
        if [[ -n "$existing" && "$existing" != "null" ]]; then
            echo "$existing"
        else
            echo '{}'
        fi
        return
    fi

    if [[ "$FORCE_REFRESH" == "false" && -n "$existing" && "$existing" != "null" ]]; then
        local updated_at current_time diff
        updated_at=$(echo "$existing" | jq -r '.updated_at // 0')
        current_time=$(date +%s)
        diff=$((current_time - updated_at))
        log_debug "Found location in config. Age: $diff seconds."
        if [ $diff -lt 86400 ]; then
            log_debug "Config location is fresh. Returning existing data."
            echo "$existing"
            return
        fi
    fi

    log_debug "Fetching location details..."
    local raw_loc
    raw_loc="$(fetch_ip_location)"

    if [[ -n "$raw_loc" && "$raw_loc" != "null" ]]; then
        log_debug "Geolocation retrieved successfully."
        local now
        now=$(date +%s)
        local final_loc
        final_loc=$(echo "$raw_loc" | jq --argjson ts "$now" '. + {updated_at: $ts}')
        save_location "$final_loc"
        echo "$final_loc"
    elif [[ -n "$existing" && "$existing" != "null" ]]; then
        log_debug "All providers failed. Falling back to existing config location."
        echo "$existing"
    else
        log_debug "No location data or config available. Defaulting to fallback payload."
        local fallback
        fallback='{"latitude": 0.0, "longitude": 0.0, "city": "Unknown", "region": "Unknown", "country_name": "Unknown", "timezone": "UTC", "updated_at": 0}'
        save_location "$fallback"
        echo "$fallback"
    fi
}


resolve_location
