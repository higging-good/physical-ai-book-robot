FROM robotis/open-manipulator:5.0.0

SHELL ["/bin/bash", "-c"]

COPY ros2_ws/src /root/bimanual_ws/src

RUN source /opt/ros/jazzy/setup.bash \
    && source /root/ros2_ws/install/setup.bash \
    && cd /root/bimanual_ws \
    && colcon build --symlink-install

COPY config/fastdds_udp_only.xml /root/fastdds_udp_only.xml

WORKDIR /root/bimanual_ws
CMD ["bash"]

