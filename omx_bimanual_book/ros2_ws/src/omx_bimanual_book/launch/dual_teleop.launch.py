from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, TimerAction

from omx_bimanual_book.launch_helpers import follower_group, leader_group


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument("left_follower_port"),
        DeclareLaunchArgument("left_leader_port"),
        DeclareLaunchArgument("right_follower_port"),
        DeclareLaunchArgument("right_leader_port"),
        follower_group("left", "left_follower_port", teleop=True),
        follower_group("right", "right_follower_port", teleop=True),
        TimerAction(period=10.0, actions=[
            leader_group("left", "left_leader_port"),
            leader_group("right", "right_leader_port"),
        ]),
    ])

