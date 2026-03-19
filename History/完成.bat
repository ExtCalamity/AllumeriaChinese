@echo off
echo 准备将新完成的汉化文件迁移至模组目录下
pause

REN  "keys - 0.14.8-CN-NEW.txt" "keys.txt"
echo 已重命名
MOVE "keys.txt" "../res/translations/zh-CN/keys.txt"
echo 已移动文件

pause