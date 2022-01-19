import json
import boto3
import datetime

dynamodb = boto3.resource('dynamodb')


def get_handler(event, context):
    table = dynamodb.Table('copy')
    response = table.get_item(Key={'id': 'joe'})
    buffer = response['Item']['buffer']

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
            'content-type': 'application/json'
        },
        'body': json.dumps(buffer)
    }

def save_handler(event, context):
    table = dynamodb.Table('copy')
    table.put_item(
       Item={
            'id': 'joe',
            'buffer': event['body']
        }
    )

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET',
            'content-type': 'application/json'
        }
    }