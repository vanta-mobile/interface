# 账户／子账户接口与 PRD 差异核对

核对日期：2026-11-09。范围为当前设计入口、账户切换、子账户创建／管理和账户间划转；不把已有底层协议、保留的旧页面或 mock 成功等同于完整产品流程完成。本次为只读代码／协议审计与本地文档修正，没有修改业务代码或远端 PRD，没有执行真实签名／私有请求／资金操作。

## 来源

- [正式 PRD 的子账户全局状态](https://app.notion.com/p/408080d974e780948843d8577f0065ca)，工具返回最后编辑时间 2026-11-09T02:17:01.518Z。
- [账户登录＋子账户模块](https://app.notion.com/p/408080d974e7803f8710f5e688c0d103)，工具返回最后编辑时间 2026-11-06T08:29:32.497Z；以本次获取的完整页面内容为基准，页面中的部分接口核查表保留 10 月 30 日日期。
- [Aster 官方 Futures V3](https://github.com/asterdex/api-docs/blob/master/V3%28Recommended%29/EN/aster-finance-futures-api-v3.md)，本次匿名读取的完整文件 SHA-256：`8bbd1acdfd60d9b43ad7facd80b8cf55f0a2e30a65e5917231e26cacb7f0c3f9`。
- 用户在本会话明确确认：由 App 自动生成独立子钱包。
- 当前 `lib/features/subaccounts/`、账户身份切换实现、提现资格预检及实际导航。

## 接口说明覆盖情况

| 能力 | 官方合同 | 当前说明／实现边界 |
| --- | --- | --- |
| 创建 | `POST /fapi/v3/createSubAccount`；子 EOA 先签不含 childSignature 的查询，主钱包再签含 childSignature 的查询；EVM EIP-712 chainId=1666 | 参数、签名顺序和 code/msg 响应有说明并已实现。私钥由 App 先生成并保存；API 不生成／返回私钥。真实自 signer 接受性待验证 |
| 列表 | `GET /fapi/v3/getSubAccountList`；nonce/user/signer 与签名 | 只给 accountId、subAccountName、parentAccount，没有地址映射、余额或实时冻结状态。列表查询不是切换授权接口 |
| 冻结／解冻 | `POST /fapi/v3/updateSubAccount`；主钱包签名，status 为 FROZEN/NORMAL | 已接入命令和受理日志；没有独立、已接入的实时状态查询。不能将冻结受理解释成撤销挂单、停止 TP/SL 或处理现有仓位 |
| 账户间划转 | `POST /fapi/v3/subAccountTransfer`；四种 kindType，签名者取决于 user 或授权 signer | 合同支持四种市场方向及主／子签名场景；新产品页面仅接入当前账户 Futures→Futures。冻结账户不能转入／转出 |
| 绑定已有钱包 | `POST /fapi/v3/sub-accounts/bind` 同样要求子钱包证明和主钱包签名 | 填地址本身不能证明钱包控制权；不是只提供一个地址就完成关联。此绑定入口未接入当前自动生成流程 |
| 切换账户 | 没有将列表查询等同于切换的官方独立端点 | App 先由当前钱包签署独立 Vanta 切换意图并本地验签，再核对目标连接并替换单一活跃身份；本机已备份子账户使用设备连接 |
| 未知写入恢复 | 当前已核查的合同没有提供本实现可依赖的、按原请求 nonce 唯一核对未知子账户划转结果的查询 | 保留公开意图日志并阻止重复发送；余额变化不能作为原请求成功证据。不能描述为完整自动对账已完成 |

结论：四个主要读写接口的请求说明具备，完整产品所需的地址映射、实时状态／其他子账户余额、未知写入对账合同并不齐全。也不能用“接口有四种方向”证明新 UI 已支持四种方向。

## 与 PRD 的逐项差异

| 项目 | PRD／已确认要求 | 当前代码事实 | 判定 |
| --- | --- | --- | --- |
| 四种市场方向 | 任意主／子账户的 Spot 或 Futures 转到任意主／子账户的 Spot 或 Futures | `application/account_transfer_provider.dart` 的 direction 固定 FUTURE_FUTURE，来源固定当前身份；旧管理页的方向选择没有接入新导航 | 实现缺口，不能归因于接口不支持 |
| 主账户代选子账户转出 | 任意关联主／子之间资金转移；官方支持 master 为子→子签名 | 新页不能选择其他来源；`data/subaccount_management_repository.dart` 要求签名地址至少是 from/to 之一，主账户代理两个子账户的场景也被拦截 | 实现范围不足 |
| Privy 非创建操作 | 只明确禁止 Privy 托管钱包创建子账户 | `canManageAccountsProvider` 要求 external，导致新管理入口及读取／冻结受限；新划转控制器也要求 external；选择器只给托管身份显示当前账户 | 限制扩大，应将创建资格与其他操作资格分离；其他操作仍须 Aster 核验 |
| 已有远端账户下拉切换 | 用户可从列表选择主／子账户操作 | 地址关系仅来自本机已受理创建日志。远端目录卡无可操作地址，不能直接切换／冻结／选择划转目标；同名本地和远端条目可能并存 | 产品缺口加协议字段缺口，不能按 ID 或名字猜地址 |
| 未知地址的主／子角色 | 主／子身份明确，子账户不得对外提现 | 没有本机关联记录或有效主账户目录证据的地址显示通用账户，不默认标 main；已知子账户的提现入口显示“仅主账户可提现”并禁用，未知账户仍由提现仓库做 master 目录资格预检 | 角色与入口已修正；真实子账户拒绝提现仍需联调验收 |
| 冻结后能否切换查看 | PRD 明确拦截跨账户划转；明确注明登录、切换、查看等影响未确定 | `AccountSwitchScreen` 禁用 freezeRequested 目标；详情页改为解冻入口 | 当前是额外产品限制，不能说是官方冻结协议要求 |
| 创建返回地址／私钥 | 原 PRD 写“系统返回地址＋私钥、用户手动保存”；用户已确认 App 自动生成 | App 本机生成 EOA、先安全保存，再自动子签名＋主钱包签名；备份由用户确认。密钥会持续保存在设备安全存储以支持后续切换 | 符合 PRD／设计的系统生成钱包并由用户备份流程；“系统返回”不限定服务端，不能解释为 Aster API 返回私钥 |
| 切换签名 | 原 PRD 两处写“切换需要钱包签名授权” | 切换先签独立 EIP-712 切换意图（绑定当前地址、目标地址、随机 nonce 和两分钟有效期），本地校验签名后才切换；拒签／无效签名保持旧身份；初次连接登录仍不增加签名 | 切换签名已补齐；此意图只用于 App 本地切换，不是交易所登录凭证或资金授权 |
| 子账户状态／资产数值 | 设计给出 Enabled/Frozen 和余额示例，PRD 需要活跃账户数据 | 本机已备份且有受理创建关系的子钱包通过独立签名读取 Futures 余额，保留各资产单位；其他远端子账户余额仍未知。冻结仅反映本机命令记录，其他设备修改不能由目录刷新核实 | 本机余额已补齐；远端地址映射／其他账户余额及实时冻结状态仍缺可靠读源 |

已核对保留的要求：EOA 创建限制、创建时最多十个的目录预检、单一活跃身份、切换失败保持旧身份、两阶段余额复核、Decimal 金额、冻结意图划转拦截、写前日志和未知结果不重放均有代码及既有自动测试。以上不代表真实 Aster 账户受理、真实设备密钥恢复或提现边界已验收。

## 文档状态

本次修正 `prd-progress.md` 和 `remaining-work.md` 的当前子账户条目，移除“尚未生成私钥”以及“当前流程已完整支持四种方向”的过时描述。

`reference/account-funding-operations-public-contract.json`、`subaccount-list-public-contract.json`、`subaccount-creation-access-public-contract.json` 是 11 月 3—5 日的历史快照，其中手动子签名、SIWE、无本机钱包生成及旧页面权限的描述不代表当前入口；保留历史证据，不覆盖旧验证记录。本报告与 `implementation.md` 最新章节说明当前状态。没有将这些本地修正写回 Notion。

本次仅更新文档，执行差异／空白检查；未重新运行 Flutter 测试或构建。

## 本次调整后的边界

账户切换签名、未知角色展示、已知子账户提现入口及备份后返回列表已修正。本机已备份子钱包的余额读取、独立连接释放、账户变化取消、错误保留与完整刷新等待已接入。备份完成回到账户列表，用户再选择新建账户详情。

不通过账户名称或数字 ID 猜测地址，因此官网／其他设备已有子账户仍只有目录展示，不能在当前入口直接操作，也无法可靠合并它与本机地址卡。Aster 官方列表合同仍缺地址和实时冻结字段；不能将 canTrade 或账户余额推断为 Frozen／Enabled。Privy 权限、Spot／Futures 范围、当前账户作为 From 以及产品未定规则，保持已记录的设计范围。

## 官网补充只读接口发现

复核完整官方 API 文档仓库后，V3 列表仍只声明 ID、名称、主子标识。但官网公开前端代码另有 `POST /bapi/futures/v1/private/future/subAccount/list` 与 `getAccountInfo`：列表映射使用 `sourceAddr`、`subAccountStatus`（`FREEZE`）、`futureBalanceList`、`spotBalanceList`；当前账户信息使用 `subAccountVo.accountId/sourceAddr`。因此这里的缺口是 **App 尚未接入官网私有会话认证**，不能再笼统描述为 Aster 没有相关查询接口。

列表由官网派生钱包签署带 timestamp 的参数，客户端启用凭证 Cookie 并根据登录 Cookie 添加 CSRF 头；不能直接把现有 V3 签名参数发给它。对官网列表的一次无凭证只读请求返回 HTTP 401／`100001005`／`Please log in first.`，未尝试登录、签名或读取真实账户。发现记录见 `reference/subaccount-web-read-discovery.json`。这两个路径已定位，但没有把源码推导的合同当成已完成认证联调或已接入的功能。
