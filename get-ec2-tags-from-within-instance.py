import boto3
import requests


def _get_metadata_region():
    r = requests.get(
        'http://169.254.169.254/latest/dynamic/instance-identity/document')

    return r.json()['region']


def _get_instance_id():
    r = requests.get('http://169.254.169.254/latest/meta-data/instance-id')
    return r.text


def get_instance_tags():
    client = boto3.client('ec2', region_name=_get_metadata_region())
    response = client.describe_tags(
        Filters=[
            {
                'Name': 'resource-id',
                'Values': [
                    _get_instance_id(),
                ]
            },
        ],
    )
    print(response['Tags'])


get_instance_tags()
