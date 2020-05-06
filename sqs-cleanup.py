#!/bin/python

import boto3
from datetime import datetime

# Defines if a queue gets deleted or just printed
DRY_RUN = False
# A prefix for names to list from AWS
# To list all of them leave empty
QUEUE_PREFIX = 'bulletins-filters-results-queue'
# Age in days defines which queues gets removed
AGE_TO_DELETE = 30


def get_queues(sqs_client):
    return sqs_client.list_queues(
        QueueNamePrefix=QUEUE_PREFIX
    )


def has_a_number(queue_url):
    name = queue_url.split('/')[-1]
    return any(char.isdigit() for char in name)


def get_creation_date(url):
    return sqs_client.get_queue_attributes(
        QueueUrl=url,
        AttributeNames=[
            'CreatedTimestamp'
        ]
    )


def get_queue_age(creation_date):
    now = datetime.now()
    normal_date = datetime.utcfromtimestamp(int(creation_date))
    age = (now - normal_date)
    return age.days


def delete_quque(sqs_client, queue_url):
    print(sqs_client.delete_queue(QueueUrl=queue_url))


def remove_old_queues(queues):
    for url in queues.get('QueueUrls'):
        created = get_creation_date(url)
        creation_date = created.get('Attributes').get('CreatedTimestamp')
        age_days = get_queue_age(creation_date)
        if age_days >= AGE_TO_DELETE and has_a_number(url):
            print('Deleting {} [dryrun:{}]'.format(url, DRY_RUN))
            if not DRY_RUN:
                delete_quque(sqs_client, url)
            break


if __name__ == '__main__':
    sqs_client = boto3.client('sqs')
    queues = get_queues(sqs_client)
    remove_old_queues(queues)
