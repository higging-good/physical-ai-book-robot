from launch.actions import ExecuteProcess, GroupAction, RegisterEventHandler
from launch.event_handlers import OnProcessExit
from launch.substitutions import Command, FindExecutable, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node, PushRosNamespace
from launch_ros.substitutions import FindPackageShare


ROOT_NAMESPACE = "bimanual"


def _robot_description(robot_model: str, prefix: str, port_name: LaunchConfiguration):
    return Command([
        PathJoinSubstitution([FindExecutable(name="xacro")]),
        " ",
        PathJoinSubstitution([
            FindPackageShare("open_manipulator_description"),
            "urdf",
            robot_model,
            f"{robot_model}.urdf.xacro",
        ]),
        " prefix:=", prefix,
        " use_sim:=false",
        " use_mock_hardware:=false",
        " mock_sensor_commands:=false",
        f" ros2_control_type:={robot_model}",
        " port_name:=", port_name,
    ])


def follower_group(side: str, port_argument: str, teleop: bool) -> GroupAction:
    prefix = f"{side}_"
    namespace = f"{ROOT_NAMESPACE}/{side}/follower"
    description = _robot_description("omx_f", prefix, LaunchConfiguration(port_argument))
    config = PathJoinSubstitution([
        FindPackageShare("omx_bimanual_book"),
        "config",
        f"{side}_follower_controllers.yaml",
    ])
    remappings = []
    if teleop:
        remappings.append((
            f"/{namespace}/arm_controller/joint_trajectory",
            f"/{ROOT_NAMESPACE}/{side}/leader/joint_trajectory",
        ))

    control_node = Node(
        package="controller_manager",
        executable="ros2_control_node",
        parameters=[{"robot_description": description}, config],
        remappings=remappings,
        output="screen",
    )
    spawner = Node(
        package="controller_manager",
        executable="spawner",
        arguments=[
            "arm_controller",
            "joint_state_broadcaster",
            "--controller-manager",
            f"/{namespace}/controller_manager",
        ],
        parameters=[{"robot_description": description}],
        output="screen",
    )
    state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        parameters=[{
            "robot_description": description,
            "use_sim_time": False,
            "frame_prefix": f"{ROOT_NAMESPACE}/{side}/follower/",
        }],
        output="screen",
    )
    return GroupAction([
        PushRosNamespace(namespace),
        control_node,
        spawner,
        state_publisher,
    ])


def leader_group(side: str, port_argument: str) -> GroupAction:
    prefix = f"{side}_"
    namespace = f"{ROOT_NAMESPACE}/{side}/leader"
    description = _robot_description("omx_l", prefix, LaunchConfiguration(port_argument))
    config = PathJoinSubstitution([
        FindPackageShare("omx_bimanual_book"),
        "config",
        f"{side}_leader_controllers.yaml",
    ])

    control_node = Node(
        package="controller_manager",
        executable="ros2_control_node",
        parameters=[{"robot_description": description}, config],
        output="screen",
    )
    spawner = Node(
        package="controller_manager",
        executable="spawner",
        arguments=[
            "joint_state_broadcaster",
            "trigger_position_controller",
            "joint_trajectory_command_broadcaster",
            "--controller-manager",
            f"/{namespace}/controller_manager",
        ],
        parameters=[{"robot_description": description}],
        output="screen",
    )
    state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        parameters=[{
            "robot_description": description,
            "use_sim_time": False,
            "frame_prefix": f"{ROOT_NAMESPACE}/{side}/leader/",
        }],
        output="screen",
    )
    trigger_command = ExecuteProcess(
        cmd=[
            "ros2", "topic", "pub",
            "-r", "50", "-t", "50", "-p", "50",
            f"/{namespace}/trigger_position_controller/commands",
            "std_msgs/msg/Float64MultiArray",
            "data: [-0.7]",
        ],
        output="screen",
    )
    trigger_after_spawn = RegisterEventHandler(
        OnProcessExit(target_action=spawner, on_exit=[trigger_command])
    )
    return GroupAction([
        PushRosNamespace(namespace),
        control_node,
        spawner,
        state_publisher,
        trigger_after_spawn,
    ])
