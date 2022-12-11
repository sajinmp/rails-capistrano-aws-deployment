#!/bin/bash

#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
# Run tests, Deploy code, Update Ami and Create new launch template version
# -------------------------------------------------------------------------
# Fetches details using aws cli. Deploys the code to all active instances
# of the autoscaling group. Removes the oldest Ami-image and generate a new
# image from the deployed instance. Create a new version of launch template 
# based on the latest version, updates the ami image and set it as default.
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

# ----------------------------------------------------------------
# Fetch instances under autoscaling group and get instance details
# ----------------------------------------------------------------

autoscaling_resp=$(aws autoscaling describe-auto-scaling-instances)
launch_template_id=$(jq -r '.AutoScalingInstances[0].LaunchTemplate.LaunchTemplateId' <<< $autoscaling_resp)
autoscaling_group_name=$(jq -r '.AutoScalingInstances[0].AutoScalingGroupName' <<< $autoscaling_resp)
instance_ids=$(jq -r '.AutoScalingInstances[].InstanceId' <<< $autoscaling_resp)

instance_details=$(aws ec2 describe-instances --instance-ids ${instance_ids[@]} | jq '.Reservations[].Instances[] | {id: .InstanceId, dns: .PublicDnsName, ip: .PublicIpAddress}')
echo $instance_details

# ----------------------------------
# Deploy code to instances - Pending
# ----------------------------------

# Pending code

# -------------------------------------------------------------------------
# Fetch ami images. Remove old ami image and generate new one from instance
# -------------------------------------------------------------------------

ami_images=$(aws ec2 describe-images --owner self | jq -r '[.Images[] | {image_id: .ImageId, name: .Name, created_at: .CreationDate}]')
first_date=$(jq -r 'first | .created_at' <<< $ami_images | { read first_date; date +%s -d "$first_date"; })
last_date=$(jq -r 'last | .created_at' <<< $ami_images | { read last_date; date +%s -d "$last_date"; })

if [[ $first_date -gt $last_date ]]
then
  old_ami=$(jq -r 'last' <<< $ami_images)
else
  old_ami=$(jq -r 'first' <<< $ami_images)
fi
echo $old_ami

$(aws ec2 deregister-image --image-id $(jq -r '.image_id' <<< $old_ami))

new_ami_id=$(aws ec2 create-image --instance-id $instance_ids --name $(jq -r '.name' <<< $old_ami) --no-reboot | jq -r '.ImageId')

# -------------------------------------------------------------------------------
# Create new launch template version with the new ami-image and set it as default
# -------------------------------------------------------------------------------


current_version=$(aws ec2 describe-launch-templates --launch-template-ids $launch_template_id | jq -r '.LaunchTemplates[0].LatestVersionNumber')

new_version_resp=$(aws ec2 create-launch-template-version --launch-template-id $launch_template_id --source-version $latest_version --launch-template-data '{"ImageId": "'"$new_ami_id"'"}')

$(aws ec2 modify-launch-template --launch-template-id $launch_template_id --default-version $(jq -r '.LaunchTemplateVersion.LaunchTemplateVersion'))
