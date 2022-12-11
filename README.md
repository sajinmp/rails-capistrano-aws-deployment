# Rails - Capistrano: Deploy to AWS EC2 without Image Builder

A bash script to deploy and update code directly to Aws ec2 and update the image and launch configuration.

This script uses AWS Cli to fetch details of the active instances in an autoscaling group and initiates a deployment to the instances. Once the deployment is done, a new ami-image is generated from an active instance after which a new version of the launch template is created and set as default.

> Note: The script is also searching for an old ami-image and removing it (since I keep only 2 at a time). Please comment it out if not required.

The need for this came because of how EC2 Image Builder works. During an instance refresh, the instance is taken down first before launching a new one. This causes downtime for applications running only 1 instance.

Let me know if there are improvements that I could make to this.
