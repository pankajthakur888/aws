# -*- coding: utf-8 -*-
__author__ = "Pankaj"
__license__ = "MIT"
__email__ = "pankajkumarthakur888@gmail.com"
__maintainer__ = "Pankaj Kumar"

import json
import os
import boto3


def lambda_handler(event, context):
    # boto3 client
    s3 = boto3.client("s3")

    # replace below configuration
    bucket_name = "devops-mtv"
    key = "file_to_be_downloaded"

    # downloading file to /tmp directory within lambda
    lambda_file_path = f"/tmp/{key}"
    lambda_output_file_path = "/tmp/trancoded_file_name"

    # downloading file
    s3.download_file(bucket_name, key, lambda_file_path)

    # transcoding
    os.system(
        f"/opt/ffmpeg-lambda/ffmpeg -i {lambda_file_path} {lambda_output_file_path}"
    )

    # uploading transcoded file
    s3.upload_file(
        Bucket=bucket_name,
        Key=lambda_output_file_path.split("/")[-1],
        Filename=lambda_output_file_path,
    )

    return {"statusCode": 200, "body": json.dumps("Hello from pankaj!")}
