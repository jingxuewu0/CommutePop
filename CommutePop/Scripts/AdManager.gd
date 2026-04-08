extends Node

## ══════════════════════════════════════════════════════════════════
## AdManager — AdMob SDK 接入
## 使用插件：poingstudios/godot-admob-plugin（Asset Library 搜 "AdMob by poing.studios"）
##
## ─── 接入步骤（发布前必须完成）───────────────────────────────────
##  1. Godot Asset Library → 搜索 "AdMob" (by poing.studios) → 下载安装
##  2. Project → Project Settings → Plugins → 启用 AdMob
##  3. Project → Tools → AdMob Manager → Android → Download & Install
##  4. 将下方 ANDROID_APP_ID_REAL 填写到
##     res://addons/admob/android/config.gd 的 APPLICATION_ID
##  5. 将真实广告单元 ID 填入下方 *_REAL 常量
##  6. 将 USE_REAL_ADS 改为 true 再发布
##
## ─── 运行模式 ────────────────────────────────────────────────────
##  编辑器 / 桌面端：MobileAds singleton 不存在 → 自动进入 Stub 模式
##  Android / iOS（插件已安装）：真实 SDK 运行
## ══════════════════════════════════════════════════════════════════

# ── 配置区（发布前修改此处）────────────────────────────────────────

## false = 使用 Google 官方测试广告（开发期）
## true  = 使用真实广告（上架时必须改为 true）
const USE_REAL_ADS := false

## ⚠️ 上架前在 AdMob 控制台申请后填入真实 ID ──────────────────────
## 格式：ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY
const ANDROID_APP_ID_REAL          := "ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"
const ANDROID_INTERSTITIAL_ID_REAL := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
const ANDROID_REWARDED_ID_REAL     := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
const ANDROID_BANNER_ID_REAL       := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
## iOS（如计划上架 App Store 请填写）
const IOS_INTERSTITIAL_ID_REAL     := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
const IOS_REWARDED_ID_REAL         := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
const IOS_BANNER_ID_REAL           := "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"

## Google 官方测试广告 ID（可在任意设备测试，不产生违规）
const ANDROID_INTERSTITIAL_ID_TEST := "ca-app-pub-3940256099942544/1033173712"
const ANDROID_REWARDED_ID_TEST     := "ca-app-pub-3940256099942544/5224354917"
const ANDROID_BANNER_ID_TEST       := "ca-app-pub-3940256099942544/6300978111"
const IOS_INTERSTITIAL_ID_TEST     := "ca-app-pub-3940256099942544/4411468910"
const IOS_REWARDED_ID_TEST         := "ca-app-pub-3940256099942544/1712485313"
const IOS_BANNER_ID_TEST           := "ca-app-pub-3940256099942544/2934735716"

## 每 N 局展示一次插页广告（首局不展示）
const INTERSTITIAL_INTERVAL    := 3
## 广告加载失败后的重试间隔（秒）
const RETRY_DELAY_SECONDS      := 60.0
const _API_PREFIXES := [
	"res://addons/admob/gdscript/src/api/",
	"res://addons/admob/src/api/"
]

# ── 内部状态 ───────────────────────────────────────────────────────

var _plugin_available := false
var _games_played     := 0
var _mobile_ads       : Object

# 使用无类型变量，避免插件未安装时解析报错
var _interstitial_ad  # InterstitialAd | null
var _rewarded_ad      # RewardedAd | null
var _banner_ad        # AdView | null

## 内部信号：用于 show_*_ad() 方法的 await 等待
signal _interstitial_dismissed
signal _rewarded_dismissed

# ── 生命周期 ───────────────────────────────────────────────────────

func _ready() -> void:
	_plugin_available = Engine.has_singleton("MobileAds")
	if not _plugin_available:
		push_warning("AdManager: MobileAds 插件未安装，以 Stub 模式运行（在编辑器/PC 端为正常现象）")
		return
	_mobile_ads = Engine.get_singleton("MobileAds")
	if _mobile_ads != null and _mobile_ads.has_method("initialize"):
		_mobile_ads.call("initialize")
	# SDK 初始化后立即预加载，保证进入结算页时广告已就绪
	_load_interstitial()
	_load_rewarded()

# ── 公开 API ──────────────────────────────────────────────────────

## 记录一局结束（在 GamePlay._on_game_finished() 中调用）
func record_game_played() -> void:
	_games_played += 1

## 是否应展示插页广告（每 INTERSTITIAL_INTERVAL 局一次）
func should_show_interstitial() -> bool:
	return _games_played > 0 and _games_played % INTERSTITIAL_INTERVAL == 0

## 展示插页广告，结束后恢复（await 友好）
## 若广告未就绪则直接返回，不阻塞游戏流程
func show_interstitial_ad() -> void:
	if not _plugin_available:
		# Stub 模式：模拟短暂延迟
		await get_tree().create_timer(0.8).timeout
		return
	if _interstitial_ad == null:
		push_warning("AdManager: 插页广告未就绪，跳过")
		return
	_interstitial_ad.show()
	await _interstitial_dismissed

## 展示激励视频广告（await 友好）
## 用户看完并赚取奖励后调用 on_success；未赚取奖励则不调用
func show_reward_ad(on_success: Callable) -> void:
	if not _plugin_available:
		# Stub 模式：模拟 1.5 秒观看 + 直接发放奖励
		await get_tree().create_timer(1.5).timeout
		on_success.call()
		return
	if _rewarded_ad == null:
		push_warning("AdManager: 激励广告未就绪，直接发放奖励")
		on_success.call()
		_load_rewarded()
		return
	var listener := _new_user_earned_reward_listener()
	if listener != null:
		listener.set("on_user_earned_reward", func(_item) -> void:
			on_success.call()
		)
		_rewarded_ad.show(listener)
	else:
		push_warning("AdManager: 未找到 OnUserEarnedRewardListener，降级为无监听展示")
		_rewarded_ad.show()
	await _rewarded_dismissed

# ── Banner 广告（可选）────────────────────────────────────────────

## 展示 Banner（底部）；若已存在则复用
func show_banner() -> void:
	if not _plugin_available:
		return
	if _banner_ad != null:
		_banner_ad.show()
		return
	var ad_view_script := _load_api_script("AdView.gd")
	var ad_size_banner = _get_ad_size_banner()
	var ad_position_bottom = _get_ad_position_bottom()
	var ad_request := _new_ad_request()
	if ad_view_script == null or ad_size_banner == null or ad_position_bottom == null or ad_request == null:
		push_warning("AdManager: Banner API 不完整，跳过 banner 展示")
		return
	_banner_ad = ad_view_script.new(_get_id("banner"), ad_size_banner, ad_position_bottom)
	_banner_ad.call("load_ad", ad_request)

## 隐藏 Banner（不销毁，可再次 show()）
func hide_banner() -> void:
	if _banner_ad != null:
		_banner_ad.hide()

## 销毁 Banner，释放内存（场景切换时可调用）
func destroy_banner() -> void:
	if _banner_ad != null:
		_banner_ad.destroy()
		_banner_ad = null

# ── 广告 ID 选取 ──────────────────────────────────────────────────

func _get_id(type: String) -> String:
	var is_ios := OS.get_name() == "iOS"
	match type:
		"interstitial":
			if USE_REAL_ADS:
				return IOS_INTERSTITIAL_ID_REAL if is_ios else ANDROID_INTERSTITIAL_ID_REAL
			return IOS_INTERSTITIAL_ID_TEST if is_ios else ANDROID_INTERSTITIAL_ID_TEST
		"rewarded":
			if USE_REAL_ADS:
				return IOS_REWARDED_ID_REAL if is_ios else ANDROID_REWARDED_ID_REAL
			return IOS_REWARDED_ID_TEST if is_ios else ANDROID_REWARDED_ID_TEST
		"banner":
			if USE_REAL_ADS:
				return IOS_BANNER_ID_REAL if is_ios else ANDROID_BANNER_ID_REAL
			return IOS_BANNER_ID_TEST if is_ios else ANDROID_BANNER_ID_TEST
	return ""

func _load_api_script(relative_path: String) -> Script:
	for prefix in _API_PREFIXES:
		var path = prefix + relative_path
		if ResourceLoader.exists(path):
			var script := load(path)
			if script is Script:
				return script
	return null

func _new_api_instance(relative_path: String) -> Object:
	var script := _load_api_script(relative_path)
	if script == null:
		return null
	return script.new()

func _new_ad_request() -> Object:
	return _new_api_instance("AdRequest.gd")

func _new_user_earned_reward_listener() -> Object:
	return _new_api_instance("listeners/OnUserEarnedRewardListener.gd")

func _get_ad_size_banner():
	var ad_size_script := _load_api_script("AdSize.gd")
	if ad_size_script == null:
		return null
	return ad_size_script.get("BANNER")

func _get_ad_position_bottom():
	var ad_position_script := _load_api_script("AdPosition.gd")
	if ad_position_script == null:
		return null
	var values = ad_position_script.get("Values")
	if values == null:
		return null
	return values.get("BOTTOM")

func _error_message(err: Variant) -> String:
	if err == null:
		return "unknown"
	if err is Object and err.has_method("get"):
		return str(err.get("message"))
	return str(err)

# ── 预加载 ────────────────────────────────────────────────────────

func _load_interstitial() -> void:
	var cb := _new_api_instance("listeners/InterstitialAdLoadCallback.gd")
	var loader := _new_api_instance("InterstitialAdLoader.gd")
	var ad_request := _new_ad_request()
	if cb == null or loader == null or ad_request == null:
		push_warning("AdManager: 插页广告 API 不完整，无法加载")
		return
	cb.set("on_ad_loaded", func(ad) -> void:
		_interstitial_ad = ad
		# 广告关闭时：发信号解除 await，销毁旧实例，预加载下一个
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
			_interstitial_dismissed.emit()
			ad.destroy()
			_interstitial_ad = null
			_load_interstitial()
		# 展示失败时也要解除 await，防止永久阻塞
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
			_interstitial_dismissed.emit()
			ad.destroy()
			_interstitial_ad = null
	)
	cb.set("on_ad_failed_to_load", func(err) -> void:
		push_warning("AdManager: 插页广告加载失败 → %s" % _error_message(err))
		await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
		_load_interstitial()
	)
	loader.call("load", _get_id("interstitial"), ad_request, cb)

func _load_rewarded() -> void:
	var cb := _new_api_instance("listeners/RewardedAdLoadCallback.gd")
	var loader := _new_api_instance("RewardedAdLoader.gd")
	var ad_request := _new_ad_request()
	if cb == null or loader == null or ad_request == null:
		push_warning("AdManager: 激励广告 API 不完整，无法加载")
		return
	cb.set("on_ad_loaded", func(ad) -> void:
		_rewarded_ad = ad
		ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
			_rewarded_dismissed.emit()
			ad.destroy()
			_rewarded_ad = null
			_load_rewarded()
		ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_err) -> void:
			_rewarded_dismissed.emit()
			ad.destroy()
			_rewarded_ad = null
	)
	cb.set("on_ad_failed_to_load", func(err) -> void:
		push_warning("AdManager: 激励广告加载失败 → %s" % _error_message(err))
		await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
		_load_rewarded()
	)
	loader.call("load", _get_id("rewarded"), ad_request, cb)