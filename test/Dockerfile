FROM homebrew/brew:latest

# 以 linuxbrew 用户运行
USER linuxbrew

# 安装 ruby@3.3
RUN brew install ruby@3.3

# 模拟 post_install 逻辑的测试脚本
COPY --chown=linuxbrew:linuxbrew test_post_install.sh /tmp/test_post_install.sh
RUN chmod +x /tmp/test_post_install.sh

CMD ["/tmp/test_post_install.sh"]
