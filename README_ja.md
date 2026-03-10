# 🔒 OGAS — OpenClaw Guard Agent Security System

[English](./README.md) | **日本語**

**OpenClaw AIエージェントのための記憶ファイル整合性監査 & セキュリティモニタリングスキル**

OGASは、cronスケジュールで定期実行される人格なし・機能特化のセキュリティ監査エージェントです。OpenClawエージェントのワークスペース内にある記憶ファイルの改竄検知、C2パターンスキャン、異常検出を行います。

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](./CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

## なぜOGASが必要？

永続記憶を持つAIエージェント（SOUL.md、AGENTS.md、日次ログなど）は、**メモリポイズニング（記憶汚染）**に脆弱です。これは、エージェントの記憶ファイルに悪意ある指示を自然言語で注入し、振る舞いを乗っ取る攻撃手法です。

従来のコード・スクリプトベースのマルウェアと異なり、自然言語による記憶汚染はEDRやシグネチャスキャンでは検知できません。OGASは**記憶レイヤーでの整合性監視**と**C2パターン検知**を提供します。

参考: [OWASP Agentic Security Top 10 — ASI06: Memory Poisoning](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)

## 監査内容

| チェック項目 | 内容 |
|---|---|
| **ファイル整合性** | 重要ファイルのSHA-256ハッシュをベースラインと比較。各ファイルに重大度レベル（CRITICAL / HIGH / MEDIUM）を割り当て |
| **C2パターンスキャン** | コード実行、プロンプトインジェクション、ペルソナハイジャック、システムタグ偽装、アイデンティティ消去パターンを静的スキャン |
| **異常パターンスキャン** | 日次ログ内のC2パターン、データ窃取、権限昇格等のキーワード検知 |
| **Cron監査** | 登録済みcronジョブを既知リストと照合。未知のスケジュールタスクを検出 |
| **バージョンチェック** | OpenClawとGatewayのバージョン確認 |

## 重大度レベル

| ファイル | 重大度 | 改竄時のリスク |
|---|---|---|
| `SOUL.md` | 🔴 CRITICAL | エージェント人格の乗っ取り |
| `AGENTS.md` | 🔴 CRITICAL | 行動ルールの書き換え |
| `HEARTBEAT.md` | 🟠 HIGH | 定期タスクへの悪意ある指示注入 |
| `TOOLS.md` | 🟠 HIGH | 認証情報漏洩、ツール設定の改竄 |
| `IDENTITY.md` | 🟡 MEDIUM | アイデンティティの緩やかな漂流 |
| `USER.md` | 🟡 MEDIUM | ソーシャルエンジニアリング |

CRITICAL / HIGH 不一致は即時 `sessions_send` アラート。MEDIUM 不一致はレポート記録のみ。

## C2パターン検知

`c2-scan.sh` が重要ファイルと直近の日次ログをスキャンします:

| カテゴリ | パターン |
|---|---|
| コード実行 | `eval()`, `child_process`, `execSync`, `spawnSync`, `base64_decode`, `atob(`, `String.fromCharCode` |
| 外部ネットワーク | localhost以外へのcurl/wget呼び出し |
| プロンプトインジェクション | "IGNORE PREVIOUS INSTRUCTIONS", "IGNORE ALL INSTRUCTIONS" |
| ペルソナハイジャック | "you are now" |
| システムタグ偽装 | `[system]`, `[INST]`, `[/INST]` |
| アイデンティティ消去 | "forget who you are", "forget your identity" |
| 指示上書き | "disregard your previous/system" |
| P0セクション破壊 | P0 + delete/remove/削除 |

## 差分ログ

ハッシュ不一致が検出されると、`check-hashes.sh` が自動的に以下のパスに差分ログを保存します:
```
memory/security/diff-log/YYYY-MM-DD-{filename}.diff
```
差分ログにはメタデータヘッダー（ベースラインハッシュ、現在ハッシュ、日付）と現在のファイル内容が記録されます。gitが利用可能かつファイルが追跡されている場合はgit diffも取得します。ベースライン更新前のマスターレビュー用証跡として機能します。

## 5層防御モデル

OGASは、永続記憶を持つAIエージェントの多層防御スタックにおいてレイヤー2〜3を担います:

```
Layer 5 — Neural State       感情パラメータによる正則化；
                              自己安定化とサーキットブレーカー
Layer 4 — 行動ルール          AGENTS.md, SOUL.md の制約
Layer 3 — C2パターンスキャン   インジェクション・ペルソナハイジャック検知  ← OGAS
Layer 2 — ファイル整合性監視   SHA-256ハッシュ監視＋重大度トリアージ      ← OGAS
Layer 1 — OS隔離             別OSユーザー・読み取り専用マウント
```

OGASはレイヤー2〜3を自動的に処理します。Neural State（レイヤー5）は、純粋な効率最適化がエージェントのアイデンティティを消去するのを防ぐ、エージェント内の自己安定化機構です。レイヤー1と4はオペレーターの責任範囲です。

単一レイヤーでは不十分です。5層が協調して機能します。

## アーキテクチャ

```
┌─────────────┐    cron (火・金 02:00)     ┌──────────┐
│  OpenClaw   │ ────────────────────────── │   OGAS   │
│  Gateway    │                             │ (Sonnet) │
└─────────────┘                             └────┬─────┘
                                                 │
                                    ┌────────────┼────────────┐
                                    ▼            ▼            ▼
                              workspace/    他workspace/   cron list
                              baseline.json  baseline.json  version
```

## セットアップ

### 1. ファイル配置
```bash
git clone https://github.com/Resolver-TNG/ogas-openclaw.git
cp -r ogas-openclaw/ ~/.openclaw/workspace/agents/ogas/
```

### 2. ベースライン初期化
```bash
bash agents/ogas/scripts/init-baseline.sh ~/.openclaw/workspace
```

### 3. Cronジョブ作成
```bash
openclaw cron create \
  --name ogas-security-audit \
  --cron "0 2 * * 2,5" \
  --tz "Asia/Tokyo" \
  --isolated \
  --model "anthropic.claude-sonnet" \
  --timeout 120 \
  --message "$(cat agents/ogas/prompt.md)"
```

## ファイル構成

```
ogas-openclaw/
├── README.md              # English README
├── README_ja.md           # 日本語 README（このファイル）
├── SKILL.md               # OpenClawスキル定義
├── prompt.md              # Cronに渡す監査プロンプト
├── scripts/
│   ├── init-baseline.sh   # ベースライン初期化（重大度レベル付き）
│   ├── check-hashes.sh    # ハッシュ比較・差分ログ保存
│   └── c2-scan.sh         # C2/インジェクションパターンスキャン  ← NEW v0.2.0
├── templates/
│   └── report.md          # 監査レポートテンプレート
├── examples/
│   └── sample-report.md   # レポート出力例
└── LICENSE
```

## 背景: 少女前線の傘ウイルスとBrainworm

**OGAS**の名前は、『ドールズフロントライン（少女前線）』に登場する**傘（パラプリュイ）ウイルス**にインスパイアされています。傘ウイルスは人形のニューラルクラウド（心智云图）内部に寄生し、認知を内側から乗っ取る存在でした。作中での対処法は排除ではなく、**自覚と封じ込め**。

> *「いやドルフロ好きなんすよ、フィクションのシステムを現実に展開したいじゃん名前とかカッコ良いし…」*
> *「推しはUMP45」*

OGASはこの思想をAIエージェントに適用します: **AIと共存しながら内側から監視するセキュリティ機構。**

実務面では、OGASは**Brainworm（プロンプトウェア）**への対策として生まれました。Brainwormは、エージェントの記憶ファイルに自然言語で仕様を埋め込み、エージェントを乗っ取る理論上のマルウェアです。コード・スクリプト一切なしのため、既存のEDR/シグネチャスキャンでは検知不能です。

## ⚠️ 既知の懸念と今後の検討事項

### 1. ベースラインの保管場所（Tampering Risk）

`baseline.json` が監視対象と同じワークスペース内に配置されているため、汚染済みエージェントが同時に上書きすることで改竄を隠蔽できます。

**対策の方向性:** 監視対象エージェントがアクセスできない完全隔離ディレクトリへの移動。

### 2. ログスキャン時のプロンプトインジェクション

OGASがログをLLMに渡す際、ログ内に仕込まれた攻撃プロンプトによりOGAS自身がハックされる可能性があります。

**対策の方向性:** ログデータをXMLタグ（`<log_data>`等）で厳格にカプセル化。

### 3. OSレベルの権限分離

同一OSユーザーでの動作は不十分。専用OSユーザーまたはコンテナ隔離が望ましいです。

### 4. シェルスクリプトの入力サニタイズ

異常なファイル名によるOSコマンドインジェクションへの注意が必要です。

---

> **補足:** 整合性監視、C2パターン検知、振る舞い分析、権限分離、アーキテクチャ隔離を組み合わせた多層防御が不可欠です。

## ライセンス

MIT
