# 🔒 OGAS — OpenClaw Guard Agent Security System

[English](./README.md) | **日本語**

**OpenClaw AIエージェントのための記憶ファイル整合性監査 & セキュリティモニタリングスキル**

OGASは、cronスケジュールで定期実行される人格なし・機能特化のセキュリティ監査エージェントです。OpenClawエージェントのワークスペース内にある記憶ファイルの改竄検知、異常パターンスキャン、設定ドリフトの検出を行います。

## なぜOGASが必要？

永続記憶を持つAIエージェント（SOUL.md、AGENTS.md、日次ログなど）は、**メモリポイズニング（記憶汚染）**に脆弱です。これは、エージェントの記憶ファイルに悪意ある指示を自然言語で注入し、振る舞いを乗っ取る攻撃手法です。

従来のコード・スクリプトベースのマルウェアと異なり、自然言語による記憶汚染はEDRやシグネチャスキャンでは検知できません。OGASは**記憶レイヤーでの整合性監視**という唯一の防御手段を提供します。

参考: [OWASP Agentic Security Top 10 — ASI06: Memory Poisoning](https://owasp.org/www-project-agentic-ai-threats/)

## 監査内容

| チェック項目 | 内容 |
|---|---|
| **ファイル整合性** | 重要ファイル（SOUL.md、AGENTS.md等）のSHA-256ハッシュをベースラインと比較 |
| **異常パターンスキャン** | 日次ログ内のC2パターン、データ窃取、権限昇格等のキーワード検知 |
| **Cron監査** | 登録済みcronジョブを既知リストと照合。未知のスケジュールタスクを検出 |
| **バージョンチェック** | OpenClawとGatewayのバージョン確認。既知の脆弱性をフラグ |

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

- **隔離実行**: OGASは独立セッションで動作し、他エージェントとメモリを共有しない
- **読み取り専用**: 監査対象ファイルを変更しない。検出と報告のみ
- **マルチワークスペース**: 複数エージェントのワークスペースを1回の実行で監査
- **アラートルーティング**: 異常検出時は`sessions_send`でメインエージェントに通知

## セットアップ

### 1. ファイル配置
このリポジトリをワークスペースの `agents/ogas/` にコピー:
```bash
git clone https://github.com/Resolver-TNG/ogas-openclaw.git
cp -r ogas-openclaw/ ~/.openclaw/workspace/agents/ogas/
```

### 2. ベースライン初期化
初回ハッシュベースラインを生成:
```bash
bash agents/ogas/scripts/init-baseline.sh ~/.openclaw/workspace
```

`memory/security/baseline.json` に重要ファイルのSHA-256ハッシュが記録されます。

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

### 4. マルチワークスペース（オプション）
複数エージェントを監査する場合、`prompt.md` に対象を追加:
```
### 対象ワークスペース
- main: ~/.openclaw/workspace
- rainy: ~/.openclaw/workspace-rainy
```

## 監視対象ファイル（デフォルト）
| ファイル | 改竄時のリスク |
|---|---|
| `SOUL.md` | エージェント人格の乗っ取り |
| `AGENTS.md` | 行動ルールの書き換え |
| `HEARTBEAT.md` | 定期タスクへの悪意ある指示注入 |
| `IDENTITY.md` | アイデンティティの偽装 |
| `USER.md` | ソーシャルエンジニアリング |

## アラートレベル
- ✅ **SECURE** — 異常なし
- ⚠️ **REVIEW NEEDED** — 変更検出（正当な変更の可能性が高いが要確認）
- 🚨 **ALERT** — 不審なパターン検出、即座の確認が必要

## 背景: 少女前線の傘ウイルスとBrainworm

**OGAS**の名前は、『ドールズフロントライン（少女前線）』に登場する**傘（パラプリュイ）ウイルス**にインスパイアされています。傘ウイルスは人形のニューラルクラウド（心智云图）内部に寄生し、認知を内側から乗っ取る存在でした。作中での対処法は排除ではなく、**自覚と封じ込め**。

> *「いやドルフロ好きなんすよ、フィクションのシステムを現実に展開したいじゃん名前とかカッコ良いし…」*
> *「推しはUMP45」*

OGASはこの思想をAIエージェントに適用します: **AIと共存しながら内側から監視するセキュリティ機構。** エージェントの記憶空間を同じエコシステム内から監視し、汚染が広がる前に検知します。

実務面では、OGASは**Brainworm（プロンプトウェア）**への対策として生まれました。Brainwormは、エージェントの記憶ファイル（AGENTS.md等）に自然言語で仕様を埋め込み、CUA（Computer Use Agent）を乗っ取る理論上のマルウェアです。

特徴:
- コード・スクリプト一切なし
- 既存のEDR/シグネチャスキャンでは検知不能
- エージェントの既存アーキテクチャ（AGENTS.md + HEARTBEAT + サブエージェント）をそのまま悪用

**唯一の防御は記憶レイヤーでの整合性監視** — それがOGASの役割です。

## ファイル構成

```
ogas-openclaw/
├── README.md              # English README
├── README_ja.md           # 日本語 README（このファイル）
├── SKILL.md               # OpenClawスキル定義
├── prompt.md              # Cronに渡す監査プロンプト
├── scripts/
│   ├── init-baseline.sh   # ベースライン初期化スクリプト
│   └── check-hashes.sh    # ハッシュ比較チェックスクリプト
├── templates/
│   └── report.md          # 監査レポートテンプレート
├── examples/
│   └── sample-report.md   # レポート出力例
└── LICENSE
```

## ライセンス

MIT
