# CommutePop

这是游戏本体工程目录，使用 Godot 4.x 开发。

## 打开方式

1. 启动 Godot 编辑器
2. 选择本目录下的 `project.godot`
3. 运行默认主场景 `Scenes/MainMenu.tscn`

## 主要目录

- `Scenes/`：场景文件
- `Scripts/`：游戏逻辑脚本
- `Assets/`：音效和美术资源

## 核心系统

- `GameManager.gd`：分数、时间、存档与局内状态
- `SoundManager.gd`：统一音效播放与开关
- `Grid.gd`：棋盘交互与消除逻辑
- `MainMenu.gd`：主菜单交互
- `ResultScreen.gd`：结算界面逻辑

## 运行前提

- Godot 4.x
- 直接打开工程目录即可，无需额外依赖