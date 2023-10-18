from subprocess import Popen, PIPE

import requests
import xml.etree.ElementTree as ET
from datetime import datetime
from urllib.parse import quote
from tqdm import tqdm

ROOT_URL = "https://luxonisos.fra1.digitaloceanspaces.com"
BUILD_URL = f"{ROOT_URL}/?delimiter=/&prefix=build/"
NAMESPACE = {'s3': 'http://s3.amazonaws.com/doc/2006-03-01/'}
SEARCH_MASK = 'rae'


def get_mender(url):
    """Fetch the last modified date and key for 'dm-verity.mender' from the given URL."""
    response = requests.get(url)
    root = ET.fromstring(response.text)

    for content in root.findall('.//s3:Contents', namespaces=NAMESPACE):
        key = content.find('s3:Key', namespaces=NAMESPACE).text
        if key.endswith('dm-verity.mender'):
            last_modified_str = content.find('s3:LastModified', namespaces=NAMESPACE).text
            last_modified_date = datetime.strptime(last_modified_str, '%Y-%m-%dT%H:%M:%S.%fZ')
            return last_modified_date, key

    return None, None


def get_latest_build(url):
    """Retrieve the latest RAE build from the specified URL."""
    response = requests.get(url)
    root = ET.fromstring(response.text)
    rae_builds = [
        prefix.text for prefix in root.findall('.//s3:CommonPrefixes/s3:Prefix', namespaces=NAMESPACE)
        if SEARCH_MASK in prefix.text
    ]

    most_recent_date = None
    most_recent_key = None

    # Determine the most recent build
    for rae_build in rae_builds:
        encoded_part = quote(rae_build.split('/')[1], safe='')
        build_url = f'{BUILD_URL}{encoded_part}/'

        last_modified, key = get_mender(build_url)
        if last_modified and (not most_recent_date or last_modified > most_recent_date):
            most_recent_date = last_modified
            most_recent_key = key

    return most_recent_key


def download_build(key=None):
    if not key:
        print('No matching build found.')
        return

    download_url = f"{ROOT_URL}/{key}"
    print(f'Downloading from: {download_url}')

    response = requests.get(download_url, stream=True)
    response.raise_for_status()

    total_size = int(response.headers.get('content-length', 0))
    block_size = 1024 * 1024  # 1 MB

    sanitized_filename = key.split('/')[-1]
    with open(sanitized_filename, 'wb') as file:
        for data in tqdm(response.iter_content(chunk_size=block_size), total=total_size // block_size, unit='MB'):
            file.write(data)
    print('\nDownloaded successfully!')

    return sanitized_filename


def run_command(command):
    """Execute the provided shell command."""
    process = Popen(command, stdout=PIPE, stderr=PIPE, shell=True)
    stdout, stderr = process.communicate()

    if process.returncode != 0:
        print(f'Command failed with error: {stderr.decode()}')
    else:
        print(stdout.decode())

    return process.returncode


if __name__ == '__main__':
    build = get_latest_build(BUILD_URL)
    downloaded_file_name = download_build(build)
    ret_code = run_command(f'mender -install {downloaded_file_name}')
    if ret_code == 0:
        run_command('reboot')
    else:
        print(f'Failed to install new build. Status: {ret_code}')
