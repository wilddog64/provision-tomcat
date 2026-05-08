import json
import os
import sys

def main():
    host = os.environ.get("PROMOTION_HOST")
    user = os.environ.get("PROMOTION_USER")
    password = os.environ.get("PROMOTION_PASS")
    inventory_file = os.environ.get("PROMOTION_INVENTORY")
    vars_file = os.environ.get("PROMOTION_VARS")

    if not all([host, user, password, inventory_file, vars_file]):
        print("ERROR: Missing required environment variables for build-inventory.py", file=sys.stderr)
        sys.exit(1)

    inventory = (
        "[aws_candidates]\n"
        "aws_candidate ansible_connection=winrm ansible_host={host} "
        "ansible_user={user} ansible_password={password} ansible_port=5985 "
        "ansible_winrm_transport=ntlm ansible_winrm_scheme=http "
        "ansible_winrm_server_cert_validation=ignore ansible_become_method=runas "
        "ansible_become_user={user}\n"
    ).format(host=host, user=user, password=password)

    extra_vars = {
        "env": "stage2",
        "extract_build_number": 16,
        "extract_debug": "False",
        "skip_migration": True,
        "upgrade_step": 2,
        "tomcat_auto_start": True,
        "tomcat_candidate_enabled": True,
        "tomcat_candidate_delegate": "localhost",
        "tomcat_candidate_delegate_host": host,
        "tomcat_candidate_delegate_port": 9080,
        "tomcat_candidate_manual_control": False,
        "upgrade_java_old_version": os.environ.get("UPGRADE_JAVA_OLD_VERSION"),
        "upgrade_java_new_version": os.environ.get("UPGRADE_JAVA_NEW_VERSION"),
        "upgrade_tomcat_old_version": os.environ.get("UPGRADE_TOMCAT_OLD_VERSION"),
        "upgrade_tomcat_new_version": os.environ.get("UPGRADE_TOMCAT_NEW_VERSION"),
        "upgrade_tomcat_old_download_url": os.environ.get("UPGRADE_TOMCAT_OLD_DOWNLOAD_URL"),
        "upgrade_tomcat_new_download_url": os.environ.get("UPGRADE_TOMCAT_NEW_DOWNLOAD_URL"),
        "upgrade_tomcat_old_checksum": os.environ.get("UPGRADE_TOMCAT_OLD_CHECKSUM"),
        "upgrade_tomcat_new_checksum": os.environ.get("UPGRADE_TOMCAT_NEW_CHECKSUM")
    }

    with open(inventory_file, "w", encoding="utf-8") as f:
        f.write(inventory)

    with open(vars_file, "w", encoding="utf-8") as f:
        json.dump(extra_vars, f)

if __name__ == "__main__":
    main()
