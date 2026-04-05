#Requires AutoHotkey v2.0
#MaxThreadsPerHotkey 2
#SingleInstance Force
SendMode("Event")
CoordMode("Mouse", "Screen")
SetTitleMatchMode(2)
SetKeyDelay(30, 30)
global APP_NAME := "洛克王国世界全自动辅助"
global APP_AUTHOR := "勼欢Ryuu"
global APP_VERSION := "1.0.0"
; ============================================================
; 项目名称：洛克王国世界全自动辅助
; 作者：勼欢Ryuu
; 说明：
;   1. 运行环境为 AutoHotkey v2。
;   2. 当前脚本为前台执行模式，需要游戏窗口保持可交互。
;   3. 顶部带有 ; @config 的配置项是默认值，运行时设置优先保存到 LuoKe.ini。
; ============================================================
; ============================================================
; 内嵌配置
; ============================================================
global StartStopKey := "PgDn" ; @config
global INTERACT_ACTION_KEY := "P" ; @config
global TotalLoopMin := 1 ; @config
global ShowGuideOnStartup := 1 ; @config
global CONFIG_FILE := ResolveConfigFile()
global COLLECT_CONFIRM_DELAY_MS := 1000
global pendingSettingsStartKey := ""
global pendingSettingsInteractKey := ""
global settingsCaptureTarget := ""
global settingsCaptureInProgress := false
LoadRuntimeSettings()
if (StartStopKey = "")
    StartStopKey := "PgDn"
if (INTERACT_ACTION_KEY = "")
    INTERACT_ACTION_KEY := "P"
if (TotalLoopMin < 1)
    TotalLoopMin := 1
if (ShowGuideOnStartup != 0 && ShowGuideOnStartup != 1)
    ShowGuideOnStartup := 1
global GAME_WIN_TITLE := "洛克王国"
; 游戏内默认动作表情键为 P；如果你改过键位，请同步到设置窗口。
NormalizeHotkeyInput(rawValue) {
    normalized := Trim(rawValue)
    if (normalized = "")
        return ""
    normalized := RegExReplace(normalized, "\s+", "")

    prefix := ""
    while (normalized != "") {
        part := SubStr(normalized, 1, 1)
        if InStr("~*$<>^!+#", part) {
            prefix .= part
            normalized := SubStr(normalized, 2)
        } else {
            break
        }
    }

    if (normalized = "")
        return ""

    lowerKey := StrLower(normalized)
    aliasMap := Map(
        "pgdn", "PgDn",
        "pagedown", "PgDn",
        "pgup", "PgUp",
        "pageup", "PgUp",
        "del", "Del",
        "delete", "Del",
        "ins", "Ins",
        "insert", "Ins",
        "esc", "Esc",
        "escape", "Esc",
        "return", "Enter",
        "enter", "Enter",
        "space", "Space",
        "spacebar", "Space",
        "home", "Home",
        "end", "End",
        "tab", "Tab"
    )

    if aliasMap.Has(lowerKey) {
        normalized := aliasMap[lowerKey]
    } else if RegExMatch(lowerKey, "^f([1-9]|1[0-2])$", &match) {
        normalized := "F" match[1]
    } else if RegExMatch(lowerKey, "^[a-z]$") {
        normalized := StrUpper(lowerKey)
    } else if RegExMatch(lowerKey, "^\d$") {
        normalized := lowerKey
    } else {
        try {
            if (GetKeyVK(normalized) != 0 || GetKeySC(normalized) != 0)
                normalized := GetKeyName(normalized)
            else
                return ""
        } catch {
            return ""
        }
    }

    return prefix normalized
}

NormalizeActionKeyInput(rawValue) {
    normalized := NormalizeHotkeyInput(rawValue)
    if (normalized = "")
        return ""
    if RegExMatch(normalized, "^[~*$<>^!+#]")
        return ""
    return normalized
}

FormatHotkeyForDisplay(keyValue) {
    displayValue := Trim(String(keyValue))
    if (displayValue = "")
        return "未设置"

    prefixText := ""
    while (displayValue != "") {
        part := SubStr(displayValue, 1, 1)
        if (part = "^") {
            prefixText .= "Ctrl + "
        } else if (part = "!") {
            prefixText .= "Alt + "
        } else if (part = "+") {
            prefixText .= "Shift + "
        } else if (part = "#") {
            prefixText .= "Win + "
        } else if InStr("~*$<>", part) {
            ; 这些前缀只用于内部热键行为，不展示给用户。
        } else {
            break
        }
        displayValue := SubStr(displayValue, 2)
    }

    if (displayValue = "")
        return RTrim(prefixText, " +")
    return prefixText displayValue
}

ResolveConfigFile() {
    configName := "LuoKe.ini"
    localConfig := A_ScriptDir "\" configName
    if !A_IsCompiled
        return localConfig

    if InStr(StrLower(A_ScriptDir), "\dist\release") {
        buildRootConfig := A_ScriptDir "\..\..\LuoKe.ini"
        localExists := FileExist(localConfig)
        rootExists := FileExist(buildRootConfig)

        ; 开发环境里根目录和 dist\release 可能各留下一份配置，
        ; 启动时优先读取最近一次写入的那份，避免看起来像“没保存”。
        if localExists && rootExists {
            localModified := FileGetTime(localConfig, "M")
            rootModified := FileGetTime(buildRootConfig, "M")
            return (rootModified >= localModified) ? buildRootConfig : localConfig
        }
        if rootExists
            return buildRootConfig
    }

    return localConfig
}

GetMirrorConfigFile(primaryConfig := "") {
    if !A_IsCompiled || !InStr(StrLower(A_ScriptDir), "\dist\release")
        return ""

    localConfig := A_ScriptDir "\LuoKe.ini"
    buildRootConfig := A_ScriptDir "\..\..\LuoKe.ini"
    if (primaryConfig = "")
        primaryConfig := ResolveConfigFile()

    if (primaryConfig = localConfig)
        return buildRootConfig
    if (primaryConfig = buildRootConfig)
        return localConfig
    return ""
}

IsModifierOnlyKey(keyName) {
    lowerKey := StrLower(Trim(keyName))
    return lowerKey = "shift"
        || lowerKey = "lshift"
        || lowerKey = "rshift"
        || lowerKey = "ctrl"
        || lowerKey = "control"
        || lowerKey = "lctrl"
        || lowerKey = "rctrl"
        || lowerKey = "lcontrol"
        || lowerKey = "rcontrol"
        || lowerKey = "alt"
        || lowerKey = "lalt"
        || lowerKey = "ralt"
        || lowerKey = "lwin"
        || lowerKey = "rwin"
}

GetSettingsCaptureDisplay(keyValue, isListening, target := "") {
    if isListening {
        if (target = "start")
            return "请按下目标按键`n支持先按住 Ctrl/Alt/Shift/Win 再按其他键"
        return "请按下目标按键`n动作表情键仅支持单键录入"
    }
    return FormatHotkeyForDisplay(keyValue) "`n点击这里后重新录入"
}

GetHeldModifierPrefix() {
    prefix := ""
    if GetKeyState("Ctrl", "P")
        prefix .= "^"
    if GetKeyState("Alt", "P")
        prefix .= "!"
    if GetKeyState("Shift", "P")
        prefix .= "+"
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P")
        prefix .= "#"
    return prefix
}

RefreshSettingsCaptureUi() {
    global setGui, pendingSettingsStartKey, pendingSettingsInteractKey, settingsCaptureTarget
    if !IsSet(setGui) || !setGui
        return
    startListening := settingsCaptureTarget = "start"
    interactListening := settingsCaptureTarget = "interact"
    setGui["StartKeyCapture"].Value := GetSettingsCaptureDisplay(pendingSettingsStartKey, startListening, "start")
    setGui["InteractKeyCapture"].Value := GetSettingsCaptureDisplay(pendingSettingsInteractKey, interactListening,
        "interact")
    setGui["StartKeyCapture"].Opt("c" (startListening ? "0x2ad7bc" : "0xeff7ff"))
    setGui["InteractKeyCapture"].Opt("c" (interactListening ? "0x39d8b0" : "0xeff7ff"))
}

BeginSettingsKeyCapture(target, *) {
    global settingsCaptureTarget, settingsCaptureInProgress
    if settingsCaptureInProgress
        return
    settingsCaptureTarget := target
    settingsCaptureInProgress := true
    RefreshSettingsCaptureUi()
    SetTimer(CapturePendingSettingsKey, -10)
}

CapturePendingSettingsKey() {
    global settingsCaptureTarget, settingsCaptureInProgress, pendingSettingsStartKey, pendingSettingsInteractKey
    if !settingsCaptureInProgress || settingsCaptureTarget = ""
        return

    capturedTarget := settingsCaptureTarget
    deadline := A_TickCount + 8000

    loop {
        remainingMs := deadline - A_TickCount
        if (remainingMs <= 0)
            break

        ih := InputHook("L0 T" Format("{:.2f}", remainingMs / 1000.0))
        ih.KeyOpt("{All}", "E")
        ih.Start()
        ih.Wait()

        if (ih.EndReason != "EndKey")
            break

        capturedKey := Trim(ih.EndKey)
        if IsModifierOnlyKey(capturedKey)
            continue

        modifierPrefix := (capturedTarget = "start") ? GetHeldModifierPrefix() : ""
        if (capturedTarget = "start")
            normalizedKey := NormalizeHotkeyInput(modifierPrefix capturedKey)
        else
            normalizedKey := NormalizeActionKeyInput(capturedKey)

        settingsCaptureTarget := ""
        settingsCaptureInProgress := false

        if (normalizedKey = "") {
            RefreshSettingsCaptureUi()
            MsgBox("这个按键当前无法识别，请换一个常规键位再试。", "按键无效", "Icon!")
            return
        }

        if (capturedTarget = "start")
            pendingSettingsStartKey := normalizedKey
        else
            pendingSettingsInteractKey := normalizedKey

        RefreshSettingsCaptureUi()
        return
    }

    settingsCaptureTarget := ""
    settingsCaptureInProgress := false
    RefreshSettingsCaptureUi()
}

LoadRuntimeSettings() {
    global StartStopKey, TotalLoopMin, ShowGuideOnStartup, CONFIG_FILE, INTERACT_ACTION_KEY
    if !FileExist(CONFIG_FILE)
        return false

    try {
        savedStart := NormalizeHotkeyInput(IniRead(CONFIG_FILE, "Settings", "StartStopKey", StartStopKey))
        savedInteract := NormalizeActionKeyInput(IniRead(CONFIG_FILE, "Settings", "InteractActionKey",
            INTERACT_ACTION_KEY))
        if (savedInteract = "")
            savedInteract := NormalizeActionKeyInput(IniRead(CONFIG_FILE, "Settings", "ExtraKey", ""))
        savedTotalLoopText := Trim(IniRead(CONFIG_FILE, "Settings", "TotalLoopMin", String(TotalLoopMin)))
        savedGuideText := Trim(IniRead(CONFIG_FILE, "Settings", "ShowGuideOnStartup", String(ShowGuideOnStartup)))
    } catch {
        return false
    }

    if (savedStart != "")
        StartStopKey := savedStart
    if (savedInteract != "")
        INTERACT_ACTION_KEY := savedInteract
    if RegExMatch(savedTotalLoopText, "^\d+$")
        TotalLoopMin := savedTotalLoopText + 0
    if (savedGuideText = "0" || savedGuideText = "1")
        ShowGuideOnStartup := savedGuideText + 0
    return true
}

WriteRuntimeSettingsToFile(configFile, startKey, interactActionKey, totalLoopMin, showGuideOnStartup) {
    IniWrite(startKey, configFile, "Settings", "StartStopKey")
    IniWrite(interactActionKey, configFile, "Settings", "InteractActionKey")
    IniWrite(String(totalLoopMin), configFile, "Settings", "TotalLoopMin")
    IniWrite(String(showGuideOnStartup), configFile, "Settings", "ShowGuideOnStartup")
}

SaveRuntimeSettings(startKey, interactActionKey, totalLoopMin, showGuideOnStartup) {
    global CONFIG_FILE
    WriteRuntimeSettingsToFile(CONFIG_FILE, startKey, interactActionKey, totalLoopMin, showGuideOnStartup)

    mirrorConfig := GetMirrorConfigFile(CONFIG_FILE)
    if (mirrorConfig != "" && mirrorConfig != CONFIG_FILE)
        WriteRuntimeSettingsToFile(mirrorConfig, startKey, interactActionKey, totalLoopMin, showGuideOnStartup)
}

TrySaveRuntimeSettings(startKey, interactActionKey, totalLoopMin, showGuideOnStartup) {
    try {
        SaveRuntimeSettings(startKey, interactActionKey, totalLoopMin, showGuideOnStartup)
        return true
    } catch as err {
        MsgBox("保存设置失败。`n`n" err.Message, "保存失败", "Icon!")
        return false
    }
}

; 注册热键
try Hotkey(StartStopKey, ToggleMacro, "On")

; ============================================================
; 洛克王国挂机脚本
; 当前为前台执行模式
; 流程：
;   1. 激活《洛克王国》窗口并执行按键流程
;   2. 执行 123456 与屏幕点击
;   3. 按倒计时执行大循环
;   4. 持续运行直到手动停止
running := false

; 面板状态变量
runStartTime := 0
totalCycleDuration := TotalLoopMin * 60000
totalCycleStartTick := 0
totalCycleActive := false
statusText := "待机中 - 按 " FormatHotkeyForDisplay(StartStopKey) " 启动"
guideGui := 0

; ============================================================
; UI 缩放
global UIRatio := A_ScreenWidth / 2560.0
if (UIRatio < 0.85)
    UIRatio := 0.85

SR(val) {
    return Integer(val * UIRatio)
}

FS(val) {
    return val * UIRatio
}

TextControlH(fontSize, minBase := 0, factor := 2.35) {
    h := Ceil(FS(fontSize) * factor)
    if (minBase > 0)
        h := Max(h, SR(minBase))
    return h
}

AddColorBlock(gui, options, color) {
    return gui.Add("Progress", options " c" color " Background" color " Range0-100", 100)
}

BringControlToFront(ctrl) {
    if !IsObject(ctrl) || !ctrl.Hwnd
        return
    DllCall("SetWindowPos"
        , "Ptr", ctrl.Hwnd
        , "Ptr", 0
        , "Int", 0
        , "Int", 0
        , "Int", 0
        , "Int", 0
        , "UInt", 0x0003)
}

TrySetDwmWindowAttributeInt(hwnd, attribute, value) {
    data := Buffer(4, 0)
    NumPut("Int", value, data)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", attribute, "Ptr", data.Ptr, "Int", 4)
}

ApplyModernWindowChrome(gui) {
    hwnd := gui.Hwnd
    if !hwnd
        return false
    ; Win11/Win10 深色标题栏与圆角，失败时静默跳过。
    TrySetDwmWindowAttributeInt(hwnd, 20, 1)
    TrySetDwmWindowAttributeInt(hwnd, 19, 1)
    TrySetDwmWindowAttributeInt(hwnd, 33, 2)
    return true
}

PanelNcHitTest(wParam, lParam, msg, hwnd) {
    global panelGui, panelToggleHwnd, panelCloseHwnd, panelToggleX, panelDragZoneH
    if !IsSet(panelGui) || !panelGui
        return

    rootHwnd := hwnd
    if (hwnd != panelGui.Hwnd) {
        try rootHwnd := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        catch
            return
        if (rootHwnd != panelGui.Hwnd)
            return
    }

    if (hwnd = panelToggleHwnd || hwnd = panelCloseHwnd)
        return

    mouseX := lParam & 0xFFFF
    mouseY := (lParam >> 16) & 0xFFFF
    if (mouseX >= 0x8000)
        mouseX -= 0x10000
    if (mouseY >= 0x8000)
        mouseY -= 0x10000

    WinGetPos(&panelX, &panelY, , , "ahk_id " panelGui.Hwnd)
    localX := mouseX - panelX
    localY := mouseY - panelY

    if (localX >= 0 && localY >= 0 && localY <= panelDragZoneH && localX < panelToggleX - SR(8))
        return 2
}

ResizeHudPanel(nextH) {
    global panelGui, panelW
    WinGetPos(&panelX, &panelY, , , "ahk_id " panelGui.Hwnd)
    panelGui.Show("x" panelX " y" panelY " w" panelW " h" nextH " NoActivate")
    WinSetRegion("0-0 w" panelW " h" nextH " R14-14", panelGui)
}

TogglePanelCollapse(*) {
    global panelCollapsed, panelExpandedH, panelCollapsedH, panelGui
    panelCollapsed := !panelCollapsed
    panelGui["PanelToggleBtn"].Value := panelCollapsed ? "+" : "-"
    ResizeHudPanel(panelCollapsed ? panelCollapsedH : panelExpandedH)
}

ExitPanelApp(*) {
    ExitApp
}

; ============================================================
; 创建状态面板
; ============================================================
panelGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
panelGui.BackColor := "0x08111f"
panelGui.MarginX := 0
panelGui.MarginY := 0

topMargin := SR(22)
sectionGap := SR(18)
runtimeSectionW := SR(208)
cycleSectionW := SR(230)
settingsSectionW := SR(188)

runtimeX := topMargin
divider1X := runtimeX + runtimeSectionW + SR(8)
cycleX := divider1X + sectionGap
divider2X := cycleX + cycleSectionW + SR(8)
settingsX := divider2X + sectionGap

panelLabelFont := 10
panelValueFont := 22
panelCycleFont := 20
panelSettingsFont := 14
panelMetaFont := 9
panelStatusFont := 11

panelAccentY := SR(18)
panelLabelY := SR(30)
panelLabelH := TextControlH(panelLabelFont, 24)
panelValueH := Max(
    TextControlH(panelValueFont, 48),
    TextControlH(panelCycleFont, 44),
    TextControlH(panelSettingsFont, 36)
)
panelValueY := panelLabelY + panelLabelH - SR(2)
panelMetaH := TextControlH(panelMetaFont, 22)
panelMetaY := panelValueY + panelValueH - SR(2)
panelSectionDividerY := panelLabelY - SR(4)
panelSectionDividerH := (panelMetaY + panelMetaH) - panelSectionDividerY
panelDividerY := panelMetaY + panelMetaH + SR(12)
statusDotH := TextControlH(panelStatusFont, 22)
statusTextH := TextControlH(panelStatusFont, 32)
statusDotY := panelDividerY + SR(8)
statusTextY := panelDividerY + SR(4)
panelBottomPad := SR(18)
panelBtnW := SR(28)
panelBtnH := SR(22)
panelBtnGap := SR(6)
panelBtnY := SR(8)
panelW := settingsX + settingsSectionW + topMargin
panelH := Max(SR(186), statusTextY + statusTextH + panelBottomPad)
panelExpandedH := panelH
panelCollapsedH := Max(SR(34), panelBtnY + panelBtnH + SR(6))
panelCollapsed := false

; -----------------------------------------------
; HUD 顶部强调线
; -----------------------------------------------
AddColorBlock(panelGui, "x0 y0 w" panelW " h" SR(3), "0x2ad7bc")
AddColorBlock(panelGui, "x" runtimeX " y" panelAccentY " w" SR(48) " h" SR(2), "0x56c8ff")
AddColorBlock(panelGui, "x" cycleX " y" panelAccentY " w" SR(64) " h" SR(2), "0xf2c66d")
AddColorBlock(panelGui, "x" settingsX " y" panelAccentY " w" SR(52) " h" SR(2), "0x39d8b0")
panelCloseX := panelW - topMargin - panelBtnW
panelToggleX := panelCloseX - panelBtnGap - panelBtnW
panelDragZoneH := SR(38)
panelGui.SetFont("s" FS(10) " bold c0x8ea3b7", "Microsoft YaHei UI")
btnPanelToggle := panelGui.Add("Text", "x" panelToggleX " y" panelBtnY " w" panelBtnW " h" panelBtnH " Center Border 0x100 0x200 Background0x111b2b vPanelToggleBtn",
    "-")
panelGui.SetFont("s" FS(10) " bold c0xff8a8a", "Microsoft YaHei UI")
btnPanelClose := panelGui.Add("Text", "x" panelCloseX " y" panelBtnY " w" panelBtnW " h" panelBtnH " Center Border 0x100 0x200 Background0x1f1620",
    "X")
panelToggleHwnd := btnPanelToggle.Hwnd
panelCloseHwnd := btnPanelClose.Hwnd
btnPanelToggle.OnEvent("Click", TogglePanelCollapse)
btnPanelClose.OnEvent("Click", ExitPanelApp)

panelGui.SetFont("s" FS(panelLabelFont) " norm c0x7f96ac", "Microsoft YaHei UI")
panelGui.Add("Text", "x" runtimeX " y" panelLabelY " w" SR(88) " h" panelLabelH " BackgroundTrans", "运行状态")

panelGui.SetFont("s" FS(panelValueFont) " bold c0x5a6f84", "Bahnschrift SemiBold")
panelGui.Add("Text", "x" runtimeX " y" panelValueY " w" SR(158) " h" panelValueH " 0x200 BackgroundTrans vRuntimeVal",
"--")

panelGui.SetFont("s" FS(panelMetaFont) " norm c0x5da7d6", "Microsoft YaHei UI")
panelGui.Add("Text", "x" runtimeX " y" panelMetaY " w" SR(150) " h" panelMetaH " BackgroundTrans", "前台自动流程")

panelGui.Add("Progress", "x" divider1X " y" panelSectionDividerY " w" SR(1) " h" panelSectionDividerH " Background0x21364d"
)

panelGui.SetFont("s" FS(panelLabelFont) " norm c0x7f96ac", "Microsoft YaHei UI")
panelGui.Add("Text", "x" cycleX " y" panelLabelY " w" SR(118) " h" panelLabelH " BackgroundTrans", "白天倒计时")

panelGui.SetFont("s" FS(panelCycleFont) " bold c0xf2c66d", "Bahnschrift SemiBold")
panelGui.Add("Text", "x" cycleX " y" panelValueY " w" SR(168) " h" panelValueH " 0x200 BackgroundTrans vCycleVal",
GetCycleDisplayText())

panelGui.SetFont("s" FS(panelMetaFont) " norm c0xbfccd9", "Microsoft YaHei UI")
panelGui.Add("Text", "x" cycleX " y" panelMetaY " w" SR(140) " h" panelMetaH " BackgroundTrans", "单位：分.秒")

panelGui.Add("Progress", "x" divider2X " y" panelSectionDividerY " w" SR(1) " h" panelSectionDividerH " Background0x21364d"
)

panelGui.SetFont("s" FS(panelLabelFont) " norm c0x7f96ac", "Microsoft YaHei UI")
panelGui.Add("Text", "x" settingsX " y" panelLabelY " w" SR(90) " h" panelLabelH " BackgroundTrans", "控制中心")

panelGui.SetFont("s" FS(panelSettingsFont) " bold c0x39d8b0", "Microsoft YaHei UI")
btnSettings := panelGui.Add("Text", "x" settingsX " y" panelValueY " w" SR(132) " h" panelValueH " Center Border 0x100 0x200 Background0x0e1728",
"设置选项")
btnSettings.OnEvent("Click", ShowSettings)

panelGui.SetFont("s" FS(panelMetaFont) " norm c0x92a7bb", "Microsoft YaHei UI")
panelGui.Add("Text", "x" settingsX " y" panelMetaY " w" settingsSectionW " h" panelMetaH " BackgroundTrans vControlHint",
    "启动 " FormatHotkeyForDisplay(StartStopKey) " / 表情 " FormatHotkeyForDisplay(INTERACT_ACTION_KEY))

; -----------------------------------------------
; 第二行：状态文本
panelGui.Add("Progress", "x" SR(22) " y" panelDividerY " w" (panelW - SR(44)) " h" SR(1) " Background0x1f3245")
panelGui.SetFont("s" FS(panelStatusFont) " norm c0x39d8b0", "Microsoft YaHei UI")
panelGui.Add("Text", "x" SR(24) " y" statusDotY " w" SR(14) " h" statusDotH " 0x200 BackgroundTrans vStatusDot", "•")
panelGui.SetFont("s" FS(panelStatusFont) " norm c0xb6c6d8", "Microsoft YaHei UI")
panelGui.Add("Text", "x" SR(40) " y" statusTextY " w" (panelW - SR(62)) " h" statusTextH " 0x200 BackgroundTrans vStatusVal",
statusText)

; -----------------------------------------------
; 面板尺寸与定位
; -----------------------------------------------
panelX := (A_ScreenWidth - panelW) // 2
panelY := Integer(A_ScreenHeight * 0.035)

panelGui.Show("x" panelX " y" panelY " w" panelW " h" panelH " NoActivate")
WinSetTransparent(228, panelGui)
WinSetRegion("0-0 w" panelW " h" panelH " R14-14", panelGui)
OnMessage(0x84, PanelNcHitTest)
SetTimer(ShowStartupGuide, -200)
UpdateControlHint()
UpdateStatus(statusText)
UpdateRuntime()

; ============================================================
; 设置窗口
ShowSettings(*) {
    global StartStopKey, INTERACT_ACTION_KEY, TotalLoopMin, ShowGuideOnStartup, panelGui, setGui
    global pendingSettingsStartKey, pendingSettingsInteractKey, settingsCaptureTarget, settingsCaptureInProgress
    selectedLoopMin := Min(Max(TotalLoopMin, 1), 240)
    pendingSettingsStartKey := StartStopKey
    pendingSettingsInteractKey := INTERACT_ACTION_KEY
    settingsCaptureTarget := ""
    settingsCaptureInProgress := false

    SuspendSettingsHotkeys() {
        global StartStopKey
        try Hotkey(StartStopKey, "Off")
    }

    RestoreSettingsHotkeys() {
        global StartStopKey
        try Hotkey(StartStopKey, ToggleMacro, "On")
    }

    CloseSettings(*) {
        global settingsCaptureTarget, settingsCaptureInProgress, setGui
        settingsCaptureTarget := ""
        settingsCaptureInProgress := false
        RestoreSettingsHotkeys()
        setGui.Destroy()
        setGui := 0
    }

    AdjustLoop(step) {
        selectedLoopMin := Min(Max(selectedLoopMin + step, 1), 240)
        loopValueCtrl.Value := String(selectedLoopMin)
    }

    SuspendSettingsHotkeys()
    setW := Min(SR(386), A_ScreenWidth - SR(40))
    setH := Min(SR(438), A_ScreenHeight - SR(60))
    pad := SR(24)
    contentW := setW - (pad * 2)
    keyCaptureH := SR(56)
    selectorH := SR(40)
    selectorArrowW := SR(42)
    loopSelectorW := SR(132)
    loopValueW := loopSelectorW - selectorArrowW * 2
    titleY := SR(18)
    subY := SR(48)
    line1Y := SR(82)
    label1Y := SR(92)
    combo1Y := SR(114)
    line2Y := SR(182)
    label2Y := SR(192)
    combo2Y := SR(214)
    line3Y := SR(282)
    label3Y := SR(292)
    editY := SR(314)
    dividerY := setH - SR(68)
    btnY := setH - SR(52)
    btnH := SR(34)
    btnGuideW := SR(98)
    btnCancelW := SR(72)
    btnSaveW := SR(76)
    btnGap := SR(10)
    btnSaveX := setW - pad - btnSaveW
    btnCancelX := btnSaveX - btnGap - btnCancelW
    btnGuideX := pad

    setGui := Gui("-MinimizeBox -MaximizeBox +Owner" panelGui.Hwnd, "运行与按键设置")
    setGui.BackColor := "0x0b1220"
    setGui.MarginX := 0
    setGui.MarginY := 0

    AddColorBlock(setGui, "x0 y0 w" setW " h" SR(4), "0x2ad7bc")

    setGui.SetFont("s" FS(15) " bold c0xeff7ff", "Microsoft YaHei UI")
    setGui.Add("Text", "x" pad " y" titleY " w" contentW " h" SR(28) " BackgroundTrans", "运行与按键设置")
    setGui.SetFont("s" FS(9) " norm c0x7f96ac", "Microsoft YaHei UI")
    setGui.Add("Text", "x" pad " y" subY " w" contentW " h" SR(20) " BackgroundTrans", "点击键位框后直接录入，保存后立即生效")

    AddColorBlock(setGui, "x" pad " y" line1Y " w" SR(62) " h" SR(2), "0x56c8ff")
    setGui.SetFont("s" FS(9) " bold c0x9bb4ca", "Microsoft YaHei UI")
    setGui.Add("Text", "x" pad " y" label1Y " w" contentW " h" SR(18) " BackgroundTrans", "启动 / 停止热键")
    setGui.SetFont("s" FS(11) " bold c0xeff7ff", "Microsoft YaHei UI")
    startCaptureCtrl := setGui.Add("Text", "x" pad " y" combo1Y " w" contentW " h" keyCaptureH " Center Border 0x100 Background0x111b2b vStartKeyCapture",
        "")

    AddColorBlock(setGui, "x" pad " y" line2Y " w" SR(78) " h" SR(2), "0x39d8b0")
    setGui.SetFont("s" FS(9) " bold c0x9bb4ca", "Microsoft YaHei UI")
    setGui.Add("Text", "x" pad " y" label2Y " w" contentW " h" SR(18) " BackgroundTrans", "动作表情按键")
    setGui.SetFont("s" FS(11) " bold c0xeff7ff", "Microsoft YaHei UI")
    interactCaptureCtrl := setGui.Add("Text", "x" pad " y" combo2Y " w" contentW " h" keyCaptureH " Center Border 0x100 Background0x111b2b vInteractKeyCapture",
        "")

    AddColorBlock(setGui, "x" pad " y" line3Y " w" SR(72) " h" SR(2), "0xf2c66d")
    setGui.SetFont("s" FS(9) " bold c0x9bb4ca", "Microsoft YaHei UI")
    setGui.Add("Text", "x" pad " y" label3Y " w" contentW " h" SR(18) " BackgroundTrans", "白天倒计时（分钟）")
    AddColorBlock(setGui, "x" pad " y" editY " w" loopSelectorW " h" selectorH, "0x111b2b")
    AddColorBlock(setGui, "x" (pad + selectorArrowW) " y" (editY + SR(6)) " w" SR(1) " h" (selectorH - SR(12)),
    "0x21364d")
    AddColorBlock(setGui, "x" (pad + loopSelectorW - selectorArrowW) " y" (editY + SR(6)) " w" SR(1) " h" (selectorH -
        SR(12)), "0x21364d")
    setGui.SetFont("s" FS(10) " bold", "Microsoft YaHei UI")
    loopMinusCtrl := setGui.Add("Button", "x" pad " y" editY " w" selectorArrowW " h" selectorH, "-")
    setGui.SetFont("s" FS(12) " bold c0xeff7ff", "Microsoft YaHei UI")
    loopValueCtrl := setGui.Add("Text", "x" (pad + selectorArrowW) " y" editY " w" loopValueW " h" selectorH " Center 0x200 BackgroundTrans",
    String(selectedLoopMin))
    setGui.SetFont("s" FS(10) " bold", "Microsoft YaHei UI")
    loopPlusCtrl := setGui.Add("Button", "x" (pad + loopSelectorW - selectorArrowW) " y" editY " w" selectorArrowW " h" selectorH,
    "+")
    setGui.SetFont("s" FS(9) " norm c0x7f96ac", "Microsoft YaHei UI")
    hintTextH := TextControlH(9, 28, 2.5)
    setGui.Add("Text", "x" (pad + loopSelectorW + SR(12)) " y" (editY + SR(5)) " w" (contentW - loopSelectorW - SR(12)) " h" hintTextH " BackgroundTrans",
    "建议先从 1 分钟试跑，确认节奏后再加时。")

    AddColorBlock(setGui, "x" pad " y" dividerY " w" contentW " h" SR(1), "0x21364d")
    setGui.SetFont("s" FS(10) " norm", "Microsoft YaHei UI")
    btnGuide := setGui.Add("Button", "x" btnGuideX " y" btnY " w" btnGuideW " h" btnH, "使用说明")
    btnCancel := setGui.Add("Button", "x" btnCancelX " y" btnY " w" btnCancelW " h" btnH, "取消")
    btnSave := setGui.Add("Button", "x" btnSaveX " y" btnY " w" btnSaveW " h" btnH " Default", "保存")
    startCaptureCtrl.OnEvent("Click", BeginSettingsKeyCapture.Bind("start"))
    interactCaptureCtrl.OnEvent("Click", BeginSettingsKeyCapture.Bind("interact"))
    loopMinusCtrl.OnEvent("Click", (*) => AdjustLoop(-1))
    loopPlusCtrl.OnEvent("Click", (*) => AdjustLoop(1))
    btnGuide.OnEvent("Click", ShowUsageGuide)
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel.OnEvent("Click", CloseSettings)
    setGui.OnEvent("Close", CloseSettings)
    setGui.OnEvent("Escape", CloseSettings)
    RefreshSettingsCaptureUi()

    SaveSettings(*) {
        savedStart := NormalizeHotkeyInput(pendingSettingsStartKey)
        savedInteract := NormalizeActionKeyInput(pendingSettingsInteractKey)
        savedTotalLoopMin := selectedLoopMin
        if (savedStart == "" || savedInteract == "" || savedTotalLoopMin < 1) {
            MsgBox("启动/停止热键不能为空，支持 Ctrl/Alt/Shift/Win + 其他键。`n动作表情按键要填写单个可识别按键，例如 P、F、Tab。`n白天倒计时必须填写正整数。", "输入错误",
                "Icon!")
            return
        }
        if !TrySaveRuntimeSettings(savedStart, savedInteract, savedTotalLoopMin, ShowGuideOnStartup)
            return
        try Hotkey(StartStopKey, "Off")
        global StartStopKey := savedStart
        global INTERACT_ACTION_KEY := savedInteract
        global TotalLoopMin := savedTotalLoopMin
        global totalCycleDuration := savedTotalLoopMin * 60000
        global totalCycleStartTick, totalCycleActive, running
        try Hotkey(StartStopKey, ToggleMacro, "On")
        if running {
            totalCycleActive := false
            totalCycleStartTick := A_TickCount
            UpdateStatus("设置已更新 - 动作表情键 " FormatHotkeyForDisplay(savedInteract) "，倒计时 " savedTotalLoopMin " 分钟")
        } else {
            UpdateStatus("设置已保存 - 按 " FormatHotkeyForDisplay(StartStopKey) " 启动，动作表情键 " FormatHotkeyForDisplay(
                savedInteract))
        }
        UpdateControlHint()
        UpdateCycleDisplay()
        setGui.Destroy()
    }

    setGui.Show("w" setW " h" setH)
    BringControlToFront(startCaptureCtrl)
    BringControlToFront(interactCaptureCtrl)
    BringControlToFront(loopMinusCtrl)
    BringControlToFront(loopPlusCtrl)
    BringControlToFront(btnGuide)
    BringControlToFront(btnCancel)
    BringControlToFront(btnSave)
    ApplyModernWindowChrome(setGui)
}

ShowStartupGuide() {
    global ShowGuideOnStartup
    if ShowGuideOnStartup
        ShowUsageGuide()
}

GetUsageGuideText() {
    guideText := "1. 推荐在卡洛西亚大陆家门口设置传送点，因为那里没有怪物。`n`n"
    guideText := guideText "2. 背包带好 6 只奇丽花：1 号位用灵巧，2 到 6 号位用爱分享。`n`n"
    guideText := guideText "3. 传送到设置好的传送点后，开启脚本即可；脚本会自动执行游戏内调到早上的按键步骤，执行期间尽量不要鼠标键盘干预。`n`n"
    guideText := guideText "4. 脚本默认动作表情按键是 P；如果你在游戏里改了键位，请在脚本设置里的“动作表情按键”同步修改。`n`n"
    guideText := guideText "5. 建议先设置 1 分钟循环，观察 3 次确认无误后，再改成你平时要用的挂机时长。"
    return guideText
}

GetDisclaimerText() {
    disclaimerText := "1. 本工具仅供 AutoHotkey 与流程控制相关的学习和探索，请勿将其视为任何稳定性、安全性或收益承诺。`n`n"
    disclaimerText := disclaimerText "2. 使用本工具存在账号异常、封禁、限制、误操作、数据损失等风险；因使用本工具产生的后果均由使用者自行承担，作者概不负责。`n`n"
    disclaimerText := disclaimerText "3. 禁止传播、公开分享、倒卖、出租、二次分发或用于任何违法违规、破坏公平或影响他人权益的场景。`n`n"
    disclaimerText := disclaimerText "4. 如不同意以上内容，请立即关闭并停止使用。"
    return disclaimerText
}

ToEditText(text) {
    return StrReplace(text, "`n", "`r`n")
}

ShowUsageGuide(*) {
    global guideGui, panelGui, StartStopKey, INTERACT_ACTION_KEY, TotalLoopMin, ShowGuideOnStartup, APP_AUTHOR,
        APP_VERSION

    if guideGui {
        try {
            guideGui.Show()
            WinActivate("ahk_id " guideGui.Hwnd)
            return
        }
    }

    guideW := Min(SR(760), A_ScreenWidth - SR(48))
    guideH := Min(SR(640), A_ScreenHeight - SR(48))
    guidePad := SR(24)
    guideGap := SR(52)
    guideColW := Integer((guideW - (guidePad * 2) - guideGap) / 2)
    guideRightX := guideW - guidePad - guideColW
    guideDividerX := guideRightX - SR(26)
    guideTitleY := SR(18)
    guideSubY := SR(50)
    guideWarningY := guideSubY + SR(26)
    guideWarningH := TextControlH(10, 24)
    guideMetaY := guideWarningY + guideWarningH + SR(12)
    guideSectionY := guideMetaY + SR(46)
    guideBodyTitleY := guideSectionY + SR(14)
    guideBodyTextY := guideBodyTitleY + SR(36)
    guideFooterLineY := guideH - SR(84)
    guideCheckY := guideH - SR(66)
    guideInfoY := guideH - SR(36)
    guideBtnW := SR(124)
    guideBtnH := SR(38)
    guideBtnX := guideW - guidePad - guideBtnW
    guideBtnY := guideH - SR(70)
    guideBodyH := guideFooterLineY - guideBodyTextY - SR(22)

    guideGui := Gui("-MinimizeBox -MaximizeBox +Owner" panelGui.Hwnd, "使用说明与免责声明")
    guideGui.BackColor := "0x08111f"
    guideGui.MarginX := 0
    guideGui.MarginY := 0
    usageText := ToEditText(GetUsageGuideText())
    disclaimerText := ToEditText(GetDisclaimerText())

    AddColorBlock(guideGui, "x0 y0 w" guideW " h" SR(4), "0x2ad7bc")

    guideGui.SetFont("s" FS(16) " bold c0xeff7ff", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideTitleY " w" (guideW - guidePad * 2 - SR(140)) " h" SR(30) " BackgroundTrans",
    "首次使用前，请先阅读以下说明与风险提示")
    guideGui.SetFont("s" FS(9) " norm c0x7f96ac", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideSubY " w" (guideW - guidePad * 2 - SR(200)) " h" SR(20) " BackgroundTrans",
    "先确认流程，再开始运行，能少很多中途误操作。")
    guideGui.SetFont("s" FS(10) " bold c0xff6b6b", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideWarningY " w" (guideW - guidePad * 2 - SR(160)) " h" guideWarningH " 0x200 BackgroundTrans",
    "请以管理员身份运行")

    AddColorBlock(guideGui, "x" guidePad " y" guideMetaY " w" SR(132) " h" SR(28), "0x111b2b")
    AddColorBlock(guideGui, "x" (guidePad + SR(144)) " y" guideMetaY " w" SR(108) " h" SR(28), "0x111b2b")
    guideGui.SetFont("s" FS(9) " norm c0xc7d5e2", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" (guidePad + SR(12)) " y" (guideMetaY + SR(6)) " w" SR(110) " h" SR(16) " BackgroundTrans",
    "作者  " APP_AUTHOR)
    guideGui.Add("Text", "x" (guidePad + SR(158)) " y" (guideMetaY + SR(6)) " w" SR(84) " h" SR(16) " BackgroundTrans",
    "版本  " APP_VERSION)

    AddColorBlock(guideGui, "x" guidePad " y" guideSectionY " w" guideColW " h" SR(2), "0x2ad7bc")
    AddColorBlock(guideGui, "x" guideRightX " y" guideSectionY " w" guideColW " h" SR(2), "0xff8a7a")
    AddColorBlock(guideGui, "x" guideDividerX " y" guideSectionY " w" SR(1) " h" (guideFooterLineY - guideSectionY - SR(
        22)), "0x21364d")

    guideGui.SetFont("s" FS(12) " bold c0xeff7ff", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideBodyTitleY " w" guideColW " h" SR(24) " BackgroundTrans", "操作说明")
    guideGui.SetFont("s" FS(10) " norm c0xb8c8d8", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideBodyTextY " w" guideColW " h" guideBodyH " BackgroundTrans", usageText)

    guideGui.SetFont("s" FS(12) " bold c0xffa191", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guideRightX " y" guideBodyTitleY " w" guideColW " h" SR(24) " BackgroundTrans", "风险提示")
    guideGui.SetFont("s" FS(10) " norm c0xc8d3df", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guideRightX " y" guideBodyTextY " w" guideColW " h" guideBodyH " BackgroundTrans",
        disclaimerText)

    AddColorBlock(guideGui, "x" guidePad " y" guideFooterLineY " w" (guideW - guidePad * 2) " h" SR(1), "0x21364d")

    guideGui.SetFont("s" FS(10) " norm c0xd6e3ef", "Microsoft YaHei UI")
    checkOptions := "x" guidePad " y" guideCheckY " w" SR(220) " h" SR(24) " vDisableStartup"
    if !ShowGuideOnStartup
        checkOptions := checkOptions " Checked"
    guideGui.Add("CheckBox", checkOptions, "下次启动不再弹出")

    guideGui.SetFont("s" FS(9) " norm c0x7f96ac", "Microsoft YaHei UI")
    guideGui.Add("Text", "x" guidePad " y" guideInfoY " w" SR(260) " h" SR(18) " BackgroundTrans", "确认后即可进入控制面板。")

    guideGui.SetFont("s" FS(10) " norm", "Microsoft YaHei UI")
    btnOk := guideGui.Add("Button", "x" guideBtnX " y" guideBtnY " w" guideBtnW " h" guideBtnH " Default", "我已知悉")
    btnOk.OnEvent("Click", CloseGuide)
    guideGui.OnEvent("Close", CloseGuide)
    guideGui.OnEvent("Escape", CloseGuide)
    guideGui.Show("w" guideW " h" guideH)
    ApplyModernWindowChrome(guideGui)

    CloseGuide(*) {
        global guideGui, StartStopKey, INTERACT_ACTION_KEY, TotalLoopMin, ShowGuideOnStartup
        disableStartup := guideGui["DisableStartup"].Value = 1
        nextShowGuideOnStartup := disableStartup ? 0 : 1
        if !TrySaveRuntimeSettings(StartStopKey, INTERACT_ACTION_KEY, TotalLoopMin, nextShowGuideOnStartup)
            return
        ShowGuideOnStartup := nextShowGuideOnStartup
        guideGui.Destroy()
        guideGui := 0
    }
}

; ============================================================
; 游戏窗口与输入控制
; ============================================================
GetGameHwnd() {
    global GAME_WIN_TITLE
    return WinExist(GAME_WIN_TITLE)
}

GameWinSpec(hwnd) {
    return "ahk_id " hwnd
}

; ============================================================
; 面板刷新
; ============================================================

GetStatusAccentColor(msg) {
    if InStr(msg, "失败") || InStr(msg, "未找到") || InStr(msg, "停止") || InStr(msg, "错误")
        return "0xff8f8f"
    if InStr(msg, "已启动") || InStr(msg, "完成") || InStr(msg, "已保存") || InStr(msg, "已更新")
        return "0x39d8b0"
    return "0xb6c6d8"
}

UpdateStatus(msg) {
    global statusText, panelGui
    statusText := msg
    statusColor := GetStatusAccentColor(msg)
    panelGui["StatusDot"].Opt("c" statusColor)
    panelGui["StatusVal"].Opt("c" statusColor)
    RefreshStatusBar()
    UpdateCycleDisplay()
}

FormatCycleCountdown(ms) {
    if (ms < 0)
        ms := 0
    totalSec := Integer((ms + 999) / 1000)
    mins := Integer(totalSec / 60)
    secs := Mod(totalSec, 60)
    return Format("{:d}.{:02d}", mins, secs)
}

GetCycleDisplayText() {
    global running, totalCycleActive, totalCycleDuration, totalCycleStartTick
    if !running
        return FormatCycleCountdown(totalCycleDuration)
    if totalCycleActive
        return "执行中"
    if (totalCycleStartTick = 0)
        return FormatCycleCountdown(totalCycleDuration)

    remaining := totalCycleDuration - (A_TickCount - totalCycleStartTick)
    if (remaining < 0)
        remaining := 0
    return FormatCycleCountdown(remaining)
}

RefreshStatusBar() {
    global panelGui, statusText
    panelGui["StatusVal"].Value := statusText
}

UpdateControlHint() {
    global panelGui, StartStopKey, INTERACT_ACTION_KEY
    panelGui["ControlHint"].Value := "启动 " FormatHotkeyForDisplay(StartStopKey) " / 表情 " FormatHotkeyForDisplay(
        INTERACT_ACTION_KEY)
}

UpdateCycleDisplay() {
    global panelGui, totalCycleActive
    panelGui["CycleVal"].Value := GetCycleDisplayText()
    panelGui["CycleVal"].Opt("c" (totalCycleActive ? "0x39d8b0" : "0xf2c66d"))
}

UpdateRuntime() {
    global running, runStartTime, panelGui

    if !running || runStartTime = 0 {
        panelGui["RuntimeVal"].Value := "--"
        panelGui["RuntimeVal"].Opt("c0x5a6f84")
    } else {
        totalSec := Integer((A_TickCount - runStartTime) / 1000)
        h := Integer(totalSec / 3600)
        m := Integer(Mod(totalSec, 3600) / 60)
        s := Mod(totalSec, 60)
        panelGui["RuntimeVal"].Opt("c0xeff7ff")
        if h > 0
            panelGui["RuntimeVal"].Value := Format("{:d}:{:02d}:{:02d}", h, m, s)
        else
            panelGui["RuntimeVal"].Value := Format("{:d}:{:02d}", m, s)
    }

    RefreshStatusBar()
    UpdateCycleDisplay()
}

StartRuntimeTimer() {
    UpdateRuntime()
    SetTimer(UpdateRuntime, 500)
}

StopRuntimeTimer() {
    SetTimer(UpdateRuntime, 0)
    ; 保留运行时长显示，不清空
    UpdateCycleDisplay()
}

RandDelay(base) {
    min := Integer(base * 0.7)
    max := Integer(base * 1.3)
    return Random(min, max)
}

WaitInterruptible(ms) {
    global running
    elapsed := 0
    while elapsed < ms && running {
        Sleep(50)
        elapsed += 50
    }
    return running
}

SmartSleep(ms) {
    return WaitInterruptible(RandDelay(ms))
}

; 带倒计时显示的等待
SmartSleepWithCountdown(ms) {
    global running
    delay := RandDelay(ms)
    elapsed := 0
    lastSec := -1
    while elapsed < delay && running {
        remainSec := Integer((delay - elapsed) / 1000)
        if remainSec != lastSec {
            UpdateStatus("等待生产中... " remainSec "s")
            lastSec := remainSec
        }
        Sleep(50)
        elapsed += 50
    }
    return running
}

WaitExactWithCountdown(ms, prefix) {
    global running
    elapsed := 0
    lastSec := -1
    while elapsed < ms && running {
        remainSec := Integer(((ms - elapsed) + 999) / 1000)
        if remainSec != lastSec {
            UpdateStatus(prefix " " remainSec "s")
            lastSec := remainSec
        }
        Sleep(50)
        elapsed += 50
    }
    return running
}

AbortMacro(reason) {
    global running, totalCycleActive, totalCycleStartTick, StartStopKey
    running := false
    totalCycleActive := false
    totalCycleStartTick := 0
    ReleaseAllKeys()
    StopRuntimeTimer()
    UpdateStatus(reason " - 按 " FormatHotkeyForDisplay(StartStopKey) " 重新启动")
}

FocusGameWindow(allowAbort := true) {
    global running
    hwnd := GetGameHwnd()
    if !hwnd {
        if allowAbort && running
            AbortMacro("未找到《洛克王国》窗口")
        return 0
    }
    winSpec := GameWinSpec(hwnd)
    if WinActive(winSpec)
        return hwnd
    try WinActivate(winSpec)
    catch {
        if allowAbort && running
            AbortMacro("激活游戏窗口失败")
        return 0
    }
    waited := 0
    while waited < 1000 {
        if WinActive(winSpec)
            return hwnd
        Sleep(50)
        waited += 50
    }
    if allowAbort && running
        AbortMacro("激活游戏窗口失败")
    return 0
}
SendKeyToGame(keys, failureReason := "按键发送失败", allowAbort := true) {
    global running
    if !FocusGameWindow(allowAbort)
        return false
    try Send(keys)
    catch {
        if allowAbort && running
            AbortMacro(failureReason)
        return false
    }
    return true
}

SendKeyUp(key) {
    SendKeyToGame("{" key " up}", "", false)
}

PressKey(key, holdMs := 300, exact := false) {
    global running
    if !running
        return false
    if !SendKeyToGame("{" key " down}", "按键发送失败")
        return false
    if exact
        WaitInterruptible(holdMs)
    else
        SmartSleep(holdMs)
    SendKeyUp(key)
    return running
}

SendHardwareKeyEvent(key, keyUp := false) {
    try {
        SendInput("{" key (keyUp ? " up}" : " down}"))
    } catch {
        return false
    }
    return true
}

PressHardwareHeldKey(key, holdMs := 300) {
    global running
    if !running
        return false
    if !FocusGameWindow()
        return false
    if !SendHardwareKeyEvent(key, false) {
        AbortMacro("按键发送失败")
        return false
    }

    WaitInterruptible(holdMs)
    SendHardwareKeyEvent(key, true)
    return running
}

TapKey(key, tapMs := 60) {
    return PressKey(key, tapMs, true)
}

SelectSpiritSlot(slot, strengthen := false) {
    global running
    key := String(slot)
    pressCount := strengthen ? 2 : 1
    holdMs := strengthen ? 120 : 90
    settleMs := strengthen ? 160 : 320

    loop pressCount {
        if !running
            return false
        if !PressKey(key, holdMs, true)
            return false
        if (A_Index < pressCount)
            WaitInterruptible(80)
    }

    WaitInterruptible(settleMs)
    return running
}

GameClickActionPoint() {
    global running
    if !running
        return false
    if !FocusGameWindow()
        return false
    clickX := A_ScreenWidth // 2
    clickY := A_ScreenHeight // 2
    DllCall("SetCursorPos", "Int", clickX, "Int", clickY)
    WaitInterruptible(70)
    Click("Down")
    WaitInterruptible(40)
    Click("Up")
    WaitInterruptible(120)
    return running
}
ReleaseAllKeys() {
    global INTERACT_ACTION_KEY
    if !FocusGameWindow(false)
        return
    keys := ["w", "f", "1", "2", "3", "4", "5", "6", "r", "x", "Escape", INTERACT_ACTION_KEY]
    sentKeys := Map()
    for k in keys {
        normalizedKey := StrLower(k)
        if sentKeys.Has(normalizedKey)
            continue
        sentKeys[normalizedKey] := true
        SendKeyUp(k)
    }
}

DeploySpirits(actionText := "收放精灵") {
    global running
    if !FocusGameWindow()
        return
    ReleaseAllKeys()
    WaitInterruptible(80)
    loop 6 {
        if !running
            return
        UpdateStatus(actionText " " A_Index "/6")
        if !SelectSpiritSlot(A_Index, A_Index = 1)
            return
        if !running
            return
        if !GameClickActionPoint()
            return
        WaitInterruptible(420)
    }
    SmartSleep(350)
    WaitInterruptible(80)
    UpdateStatus(actionText "完成")
}
IsTotalCycleDue() {
    global running, totalCycleActive, totalCycleStartTick, totalCycleDuration
    return (
        running
        && !totalCycleActive
        && (totalCycleStartTick != 0)
        && ((A_TickCount - totalCycleStartTick) >= totalCycleDuration)
    )
}

RunTotalCycle() {
    global running, totalCycleActive, totalCycleStartTick
    if !running
        return

    totalCycleActive := true
    UpdateCycleDisplay()

    UpdateStatus("白天倒计时 - 收放精灵")
    DeploySpirits("收放精灵")
    if !running {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 长按 W 300ms")
    if !PressHardwareHeldKey("w", 300) {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    if !WaitInterruptible(200) {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 按 F")
    if !PressKey("f") {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    if !WaitInterruptible(100) {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    UpdateStatus("白天倒计时 - 第二次按 F")
    if !PressKey("f") {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    WaitExactWithCountdown(6000, "白天倒计时 - 等待第一次按 1")
    if !running {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 第一次按 1")
    if !PressKey("1") {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    WaitExactWithCountdown(4000, "白天倒计时 - 等待第二次按 1")
    if !running {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 第二次按 1")
    if !PressKey("1") {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    WaitExactWithCountdown(8000, "白天倒计时 - 等待按 2")
    if !running {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 按 2")
    if !PressKey("2") {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }
    WaitExactWithCountdown(5000, "白天倒计时 - 等待收放精灵")
    if !running {
        totalCycleActive := false
        UpdateCycleDisplay()
        return
    }

    UpdateStatus("白天倒计时 - 收放精灵")
    DeploySpirits("收放精灵")

    totalCycleActive := false
    if running {
        totalCycleStartTick := A_TickCount
        UpdateStatus("白天倒计时完成 - 已重新开始计时")
    }
    UpdateCycleDisplay()
}

; ============================================================
; 主循环与开关
; ============================================================
ToggleMacro(hk) {
    global running, runStartTime, StartStopKey, totalCycleStartTick, totalCycleActive, COLLECT_CONFIRM_DELAY_MS,
        INTERACT_ACTION_KEY
    if running {
        running := false
        totalCycleActive := false
        totalCycleStartTick := 0
        ReleaseAllKeys()
        StopRuntimeTimer()
        UpdateStatus("已停止 - 按 " FormatHotkeyForDisplay(StartStopKey) " 重新启动")
        return
    }
    if !GetGameHwnd() {
        UpdateStatus("未找到《洛克王国》窗口")
        UpdateCycleDisplay()
        return
    }
    running := true
    runStartTime := A_TickCount
    totalCycleActive := false
    totalCycleStartTick := 0
    UpdateStatus("已启动 - 将在前台执行按键")
    StartRuntimeTimer()
    DeploySpirits()
    if running
        totalCycleStartTick := A_TickCount
    UpdateCycleDisplay()
    while running {
        if IsTotalCycleDue() {
            RunTotalCycle()
            continue
        }
        UpdateStatus(FormatHotkeyForDisplay(INTERACT_ACTION_KEY) " - 动作表情")
        if !TapKey(INTERACT_ACTION_KEY, 60)
            break
        SmartSleep(1000)
        if !running
            break
        UpdateStatus("2 - 生产材料")
        if !PressKey("2")
            break
        SmartSleep(300)
        if !running
            break
        UpdateStatus("Esc - 关闭面板")
        if !PressKey("Escape")
            break
        SmartSleep(300)
        if !running
            break
        UpdateStatus("1 - 开始动作")
        if !PressKey("1")
            break
        SmartSleepWithCountdown(12000)
        if !running
            break
        UpdateStatus("R - 收取资源")
        if !PressKey("r", 80, true)
            break
        if !running
            break
        WaitInterruptible(COLLECT_CONFIRM_DELAY_MS)
        if !running
            break
        UpdateStatus("X - 确认收取")
        if !PressKey("x")
            break
        SmartSleep(300)
        if !running
            break

        UpdateStatus("1 - 再次操作")
        if !PressKey("1")
            break
        SmartSleep(300)
        if !running
            break
        UpdateStatus("点击屏幕中央")
        if !GameClickActionPoint()
            break
        SmartSleep(300)
    }
}
