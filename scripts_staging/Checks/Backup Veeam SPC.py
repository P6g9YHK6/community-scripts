#!/usr/bin/python
"""
Synopsis:
    This script monitors the backup status of a specified VM or Computer
    by interfacing with the API of the Veeam Service Provider Console to 
    retrieve and analyze restore points.

    It checks if the latest backup is within a user-defined threshold
    and outputs a detailed restoration status report.

EXEMPLE:
    Mandatory:
        host={{agent.hostname}}
        apikey={{global.VeaamSPCapi}}
        apiurl=https://vspc.XXXXXX.XXXX:XXXX

    Optional
        THRESHOLD_HOURS=48
        force={{agent.Hostname_Override}}
        DEBUG=1
        force=DISABLEDBACKUPCHECK
NOTE:
    Author: SAN
    Date: 18.12.24
    #public

Outputs:
    - "OK" or "CRITICAL" status indicating backup health.
    - Detailed restoration status report if the backup check is successful.
    - Debug logs if DEBUG is set to True in the environment variables.
    - Disabled if DISABLEDBACKUPCHECK is set in FORCE

Changelog:

    27.03.25 SAN added more debug
    15.04.25 SAN big code cleanup + publication
    17.06.26 SAN server-side filter + pagination + timeouts + api key test
    18.06.26 SAN fixed api_call_with_retries raise, removed dead code, moved api key test to main, hostname fallback, consistent .get(), removed globals and isComputer dead branch
    18.06.26 SAN fixed FORCE flow, KeyError protection on vm fields, extracted resolve_host_arg/find_matching_vm, pruned TODO
    18.06.26 SAN renamed vars (r/res/resp/i/p), optimized VM matching to single-pass, added ValueError guards, cleared all TODOs
    18.06.26 SAN fixed double-limit URL bug, removed apiGet_VMbackups, use VM list fields directly for restore point data


"""

import os
import sys
import json
import time
import math
import socket
import requests
from datetime import datetime, timedelta

# === Utility Functions ===
def log_debug(msg):
    """Logs debug information if debugging is enabled."""
    if env_vars['DEBUG']:
        print(msg)

def convert_size(bytes_):
    """Converts a size in bytes to a human-readable format."""
    if bytes_ == 0:
        return "0B"
    size_index = int(math.log(bytes_, 1024))
    units = ('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB')
    return f"{round(bytes_ / (1024 ** size_index), 2)} {units[size_index]}"

def api_call_with_retries(url, method='GET', data=None, headers=None, retries=5, wait=60, timeout=60):
    """Makes an API call with retries for handling HTTP 429 responses."""
    for attempt in range(retries):
        try:
            response = requests.request(method, url, data=data, headers=headers, timeout=timeout)
            if response.status_code == 429 and attempt < retries - 1:
                print(f"HTTP 429 received. Retrying in {wait} seconds... (Attempt {attempt + 1}/{retries})")
                time.sleep(wait)
                continue
            response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            if attempt == retries - 1:
                raise
            time.sleep(wait)

def api_get_all_paginated(base_url, headers, select_param=None, **kwargs):
    """Fetches all pages from a paginated endpoint using offset-based pagination."""
    limit = 500
    offset = 0
    all_data = []

    while True:
        url = f"{base_url}?limit={limit}&offset={offset}"
        if select_param:
            url += f"&select={select_param}"
        response = api_call_with_retries(url, method='GET', headers=headers, **kwargs)
        parsed = response.json()
        data = parsed.get("data", [])

        paging = parsed.get("meta", {}).get("pagingInfo", {})
        total = paging.get("total", offset + len(data))
        if offset + limit >= total:
            break
        offset += limit

    return all_data


def get_auth_headers():
    """Returns the headers required for authenticated API requests."""
    return {
        "Connection": "close",
        "Authorization": f"Bearer {env_vars['APIKEY']}",
        "Content-Type": "application/json",
        "accept": "application/json",
    }

def apiGet_BackedUpVMs(name_filter=None):
    """Retrieves backed-up VMs, with optional server-side name filter and pagination."""
    headers = get_auth_headers()
    select = '[{"propertyPath":"name"},{"propertyPath":"instanceUid"},{"propertyPath":"backupServerUid"},{"propertyPath":"latestRestorePointDate"},{"propertyPath":"totalRestorePointSize"},{"propertyPath":"restorePoints"}]'

    if name_filter:
        url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/virtualMachines"
        filter_json = json.dumps([{"property": "name", "operation": "contains", "collation": "ignorecase", "value": name_filter}])
        url += f"?filter={filter_json}&select={select}"
        response = api_call_with_retries(url, method='GET', headers=headers, timeout=60)
        return response.json().get("data", [])

    base_url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/virtualMachines"
    return api_get_all_paginated(base_url, headers, select_param=select)

def resolve_host_arg():
    """Determines the hostname to query from FORCE, HOST, or local hostname."""
    force_val = env_vars['FORCE']
    host_arg = force_val if (force_val and "Manual" not in force_val) else env_vars['HOST']
    if not host_arg:
        host_arg = socket.gethostname()
        log_debug(f"No HOST or FORCE set. Using local hostname: {host_arg}")
    return host_arg

def find_matching_vm(backed_up_vms, host_arg):
    """Finds a unique VM matching host_arg. Returns the VM dict. Exits on zero or multiple matches."""
    if env_vars.get('FORCE'):
        matching = [vm for vm in backed_up_vms if host_arg == vm.get("name")]
    else:
        host_arg_lower = host_arg.lower()
        matching = [
            vm for vm in backed_up_vms
            if host_arg in vm.get("name", "") or host_arg_lower in vm.get("name", "")
        ]

    if not matching:
        print(f"KO: VM or Computer '{host_arg}' not found in the backup list.")
        sys.exit(2)
    elif len(matching) > 1:
        log_debug(f"WARNING: Multiple matches found for '{host_arg}':")
        for vm in matching:
            log_debug(f"  - Name: {vm.get('name', 'UNKNOWN')}, VM UID: {vm.get('instanceUid', 'UNKNOWN')}")
        print("Exiting to avoid mismatches.")
        sys.exit(2)

    matched = matching[0]
    if not matched.get("instanceUid"):
        print("KO: Selected VM is missing instanceUid.")
        sys.exit(2)
    log_debug(f"INFO: Selected VM: {matched.get('name', 'UNKNOWN')} (UID: {matched['instanceUid']})")
    return matched

# === Environment and Constants ===
env_vars = {
    'HOST': None,
    'FORCE': None,
    'DEBUG': False,
    'APIKEY': None,
    'APIURL': None,
    'THRESHOLD_HOURS': 48
}
env_vars.update({k: os.getenv(k, v) for k, v in env_vars.items()})
env_vars['DEBUG'] = str(env_vars['DEBUG']).lower() in ("true", "1")

# === Exit Early Conditions ===
if not env_vars['APIKEY'] or not env_vars['APIURL']:
    print("CRITICAL: 'APIURL' and 'APIKEY' must be set.")
    sys.exit(2)

if env_vars.get('FORCE') and "DISABLEDBACKUPCHECK" in env_vars['FORCE']:
    print("Backup check is disabled because 'FORCE' contains 'DISABLEDBACKUPCHECK'.")
    sys.exit(0)

def main():
    try:
        log_debug("Parsed Environment Variables:")
        log_debug(f"  HOST: {env_vars['HOST']}")
        log_debug(f"  FORCE: {env_vars['FORCE']}")
        log_debug(f"  DEBUG: {env_vars['DEBUG']}")
        api_key = env_vars['APIKEY']
        masked_api_key = f"{api_key[:3]}{'*' * (len(api_key) - 6)}{api_key[-3:]}"
        log_debug(f"  APIKEY: {masked_api_key}")
        log_debug(f"  APIURL: {env_vars['APIURL']}")
        log_debug(f"  THRESHOLD_HOURS: {env_vars['THRESHOLD_HOURS']}\n")

        log_debug("Testing API key validity...")
        try:
            select_json = '[{"propertyPath":"instanceUid"}]'
            test_url = f"{env_vars['APIURL']}/api/v3/protectedWorkloads/virtualMachines?limit=1&select={select_json}"
            api_call_with_retries(test_url, method='GET', headers=get_auth_headers(), retries=1, timeout=60)
        except requests.exceptions.RequestException:
            print("KO: API key is invalid or the API is unreachable.")
            sys.exit(2)

        host_arg = resolve_host_arg()

        log_debug(f"INFO: Fetching VMs filtered by name '{host_arg}'...")
        backed_up_vms = apiGet_BackedUpVMs(name_filter=host_arg)

        if not backed_up_vms:
            log_debug("Server-side filter returned no results. Falling back to full paginated fetch...")
            backed_up_vms = apiGet_BackedUpVMs()

        if not backed_up_vms:
            print(f"KO: No VMs found in backup list.")
            sys.exit(2)

        for vm in backed_up_vms:
            log_debug(f"VM Name: {vm.get('name', 'UNKNOWN')}")

        matched_vm = find_matching_vm(backed_up_vms, host_arg)
        vm_name = matched_vm.get("name", "UNKNOWN")
        latest_restore_point = matched_vm.get("latestRestorePointDate")
        restore_point_count = matched_vm.get("restorePoints", 0)
        total_restore_point_size = matched_vm.get("totalRestorePointSize", 0)

        log_debug(f"INFO: VM {vm_name}: restorePoints={restore_point_count}, latestRestorePointDate={latest_restore_point}, totalRestorePointSize={total_restore_point_size}")

        if not latest_restore_point:
            print("KO: No valid restore points found.")
            sys.exit(2)

        try:
            restore_point_time = datetime.strptime(latest_restore_point[:26], "%Y-%m-%dT%H:%M:%S.%f")
        except (ValueError, TypeError):
            print("KO: Unable to parse restore point date.")
            sys.exit(2)

        time_since_last_backup = datetime.utcnow() - restore_point_time

        try:
            threshold_hours = int(env_vars['THRESHOLD_HOURS'])
        except (ValueError, TypeError):
            print("KO: THRESHOLD_HOURS must be a number.")
            sys.exit(2)
        backup_age_limit = timedelta(hours=threshold_hours)

        if time_since_last_backup <= backup_age_limit:
            print(f"OK: The latest backup was {time_since_last_backup} ago, within the threshold of {threshold_hours} hours.")
        else:
            print(f"KO: The latest backup was {time_since_last_backup} ago, exceeding the threshold of {threshold_hours} hours.")
            sys.exit(2)

        total_restore_point_size_readable = convert_size(total_restore_point_size)

        print(f"Restoration Status Report:\n- VM or Computer: {vm_name}\n- Latest Restore Point Date/Time: {latest_restore_point}\n- Number of Restore Points Available: {restore_point_count}\n- Total Size of Restore Points: {total_restore_point_size_readable}")


    except requests.exceptions.RequestException as e:
        print("KO: API call failed.")
        log_debug("API CALL FAILED: " + str(e))
        sys.exit(2)

if __name__ == "__main__":
    main()