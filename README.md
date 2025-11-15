ChatGPTController

macOS 向けの ChatGPT API クライアントアプリ。
OpenAI API を利用してプロンプトを送信し、レスポンスを履歴として管理できます。

右下の 「loadPromptFileAndExecute」 または
「Load Folder and Execute」 ボタンから、複数プロンプトの一括実行（バッチ処理）が可能です。

⸻

🧩 主な機能

⸻

⭐ 通常モード
    •    API Key に OpenAI の API キーを入力
    •    Model, Temperature, Max Tokens, System Message, Prompt を指定
    •    Send で ChatGPT に送信
    •    得られたレスポンスは画面に表示され、履歴にも自動追加
    •    履歴は .plist で保存／読み込み可能

⸻

⭐ バッチ処理（テキストファイル方式）

複数のプロンプトを 1 行ずつ書いた .txt を自動処理。

使い方
    1.    テキストファイルを作成：

清水寺
金閣寺
銀閣寺

    2.    アプリ右下の 「loadPromptFileAndExecute」 を押す
    3.    .txt を選ぶ
    4.    各行が現在の Prompt 内容と自動結合され、ChatGPTへ送信

例：
Prompt = "について、その見どころを教えて" なら

金閣寺について、その見どころを教えて

    5.    進捗ダイアログにプログレスバーが表示
    6.    全ての回答が履歴に追加される

⸻

⭐ バッチ処理（フォルダ方式・新機能）

フォルダ内の 複数の .txt ファイルすべて を ChatGPT に送信し、
レスポンスを 同名ファイルとして保存 できるモード。

流れ
    1.    アプリ右下の 「Load Folder and Execute」 を押す
    2.    .txt が入ったフォルダを選択
    3.    出力先フォルダを指定
    4.    ファイルを 1 つずつ読み込み：

finalPrompt = (Promptフィールドの内容) + 改行 + (txtファイルの内容)

    5.    ChatGPT へ問い合わせ
    6.    レスポンスを 元と同じ名前 の .txt として保存
    7.    進行状況を専用のプログレスウィンドウに表示
    8.    「キャンセル」で途中停止可能
    9.    実行ログは History Panel にリアルタイム表示

⸻

⭐ History Panel（新機能）
    •    バッチ処理ログをリアルタイムで表示する専用パネル
    •    右側に独立ウィンドウとして表示（開閉は自由）
    •    ⌘A で全文選択が可能
    •    進行状況のデバッグに便利

⸻

💾 履歴機能
    •    Save：履歴を .plist として保存
    •    Open：履歴を読み込み
    •    Export：CSV形式（Excel互換）で出力
    •    すべてのバッチ実行内容は自動的に履歴に追加

⸻

⚙️ 技術仕様

項目    内容
対応 OS    macOS
UI    Cocoa / AppKit
言語    Objective-C
API    OpenAI Chat Completions API
通信    NSURLSession（非同期 + 同期ラップ処理）
特徴    Batch UI、History Panel、進捗ダイアログ、キャンセル処理


⸻

🪄 ビルド方法
    1.    OpenAI API Key を取得
    2.    Xcode で ChatGPTController.xcodeproj を開く
    3.    Command + R で実行
    4.    初回起動時に API Key を入力（次回以降は自動復元）

⸻

⚠️ 使用上の注意
    •    Max Tokens が小さいとレスポンスが途中で切れる場合があります
推奨：2048～4096
    •    バッチ処理中はメインウィンドウの操作が制限されます
    •    OpenAI API の利用料は個人アカウントに従って発生します
    •    同期 API を利用しているため、大量ファイル処理は数分以上かかる場合があります

⸻

📷 スクリーンショット

メイン画面    バッチ処理ダイアログ    History Panel（新）
        


⸻

🧑‍💻 作者

早川 強（AssistSystem）
教育アプリ開発者／AIツール制作者

⸻

🪪 ライセンス

MIT License
