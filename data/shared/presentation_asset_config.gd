class_name PresentationAssetConfig
extends Resource

## 跨场景共用的 UI Theme 与玩家主播固定外观资源。
@export var ui_theme: Theme

## 玩家主角供后续身份、战斗和结算画面复用的主播立绘与头像。
@export var player_streamer_portrait: Texture2D
@export var player_streamer_avatar: Texture2D

## 玩家直播间与主播标记资源。
@export var player_live_background: Texture2D
@export var player_room_background: Texture2D
@export var player_fan_badge: Texture2D
