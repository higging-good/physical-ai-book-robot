from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument

from omx_bimanual_book.launch_helpers import follower_group


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument("left_follower_port"),
        DeclareLaunchArgument("right_follower_port"),
        # PAM publishes policy actions on the configured leader trajectory
        # topics. Keep the leaders physically absent, but remap each follower
        # controller input to its corresponding PAM action topic.
        follower_group("left", "left_follower_port", teleop=True),
        follower_group("right", "right_follower_port", teleop=True),
    ])
