[![Puppet
Forge](http://img.shields.io/puppetforge/v/puppetlabs/aws.svg)](https://forge.puppetlabs.com/puppetlabs/aws)
[![Build
Status](https://travis-ci.org/puppetlabs/puppetlabs-aws.svg?branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-aws)

#### 目次

1. [概要](#概要)
2. [説明 - モジュールの機能とその有益性](#説明)
3. [セットアップ](#セットアップ)
  * [要件](#要件)
  * [awsモジュールのインストール](#awsモジュールのインストール)
4. [はじめに](#awsについて)
5. [使用方法 - 設定オプションとその他の機能](#使用方法)
  *[リソースの作成](#リソースの作成)
  * [スタックの作成](#スタックの作成)
  * [コマンド行からのリソースの管理](#コマンド行からのリソースの管理)
  * [AWSインフラストラクチャの管理](#awsインフラストラクチャの管理)
6. [参考 - モジュールの機能と動作について](#参考)
  * [タイプ](#タイプ)
  * [パラメータ](#パラメータ)
7. [制約事項 - OSの互換性など](#制約事項)

## 概要

awsモジュールは、クラウドインフラストラクチャを構築するAmazonウェブサービス(AWS)のリソースを管理します。

## 説明

Amazonウェブサービスでは、サービスプラットフォームとなるインフラストラクチャを構築、管理するための強力なAPIを公開しています。awsモジュールを使用すれば、PuppetコードでAPIを実行できます。 

最も単純なケースでは、ユーザがawsモジュールを使用してPuppetコードから新しいEC2インスタンスを作成できます。さらに重要なのは、ユーザがawsモジュールを使用してAWSインフラストラクチャ全体を記述したり、さまざまなコンポーネント間の関係をモデル化できることです。

## セットアップ

### 要件

* Puppet 3.4以降
* Ruby 1.9以降
* Amazon AWS Ruby SDK(gemとして入手可能)
* retries gem

### awsモジュールのインストール

1. Puppetと同じくRubyを使用してretries gemとAmazon AWS Ruby SDK gemをインストールします。Puppet 4.x以降の場合、gemのインストールには次のコマンドを使用します。

  '/opt/puppetlabs/puppet/bin/gem install aws-sdk-core retries'

2. AWSアクセス認証情報に応じて以下の環境変数を設定します。

  ```bash
  export AWS_ACCESS_KEY_ID=your_access_key_id
  export AWS_SECRET_ACCESS_KEY=your_secret_access_key
  ```

  または、次のテンプレートのように「~/.aws/credentials」にあるファイルに認証情報を保存することもできます。

  ```bash
 [default]
  aws_access_key_id = your_access_key_id
  aws_secret_access_key = your_secret_access_key
  ```

  AWSでPuppetを実行中にモジュールのサンプルを動作させる場合は、代わりに[IAM](http://aws.amazon.com/iam/)を使用することもできます。そのためには、サンプルを動作させる元側のインスタンスに正しい役割を割り当てます。必要なすべてのアクセス権が含まれているプロファイルのサンプルについては、[IAM profile example](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/iam-profile/)を参照してください。

3. 最後にモジュールをインストールします。

  ```bash
puppet module install puppetlabs-aws
  ```

#### リージョンについての注意事項

デフォルトでは、モジュールがAWSのすべてのリージョンを対象に使用の可否を検討するため、処理が多少遅くなる場合があります。処理する対象が分かっている場合は、環境変数を使用して対象を1つのリージョンに絞ることにより処理速度を速めることができます。

```bash
export AWS_REGION=eu-west-1
````

#### プロキシについての注意事項

既定ではモジュールは直接AWS APIにアクセスしますが、直接アクセスできない環境内ではすべてのトラフィックに対し次のようにプロキシを設定できます。

```bash
export PUPPET_AWS_PROXY=http://localhost:8888
```

#### iniファイルを使用したawsモジュールの設定

Puppet confdir ('$settings::confdir')の「puppetlabs_aws_configuration.ini」というファイルで次のフォーマットに従ってAWSリージョンとHTTPプロキシを指定できます。

```ini
    [default]
      region = us-east-1
      http_proxy = http://proxy.example.com:80
```
## awsについて

awsモジュールを使用すると、Puppet DSLによりAWSを管理できます。AWSを使用してインスタンスを立ち上げるには`ec2_instance`タイプを使用します。次のコードで、きわめて基本的なインスタンスがセットアップできます。

``` puppet
ec2_instance { 'instance-name':
  ensure        => present,
  region        => 'us-west-1',
  image_id      => 'ami-123456', # you need to select your own AMI
  instance_type => 't1.micro',
}
```

## 使用方法

###  リソースの作成

AWSのさまざまな機能、ロードバランサ、セキュリティグループを使用して、より複雑なEC2インスタンスをセットアップすることもできます。

**インスタンスのセットアップ**

``` puppet
ec2_instance { 'name-of-instance':
  ensure            => present,
  region            => 'us-east-1',
  availability_zone => 'us-east-1a',
  image_id          => 'ami-123456',
  instance_type     => 't1.micro',
  monitoring        => true,
  key_name          => 'name-of-existing-key',
  security_groups   => ['name-of-security-group'],
  user_data         => template('module/file-path.sh.erb'),
  tags              => {
    tag_name => 'value',
  },
}
```

**セキュリティグループのセットアップ**

``` puppet
ec2_securitygroup { 'name-of-group':
  ensure      => present,
  region      => 'us-east-1',
  description => 'a description of the group',
  ingress     => [{
    protocol  => 'tcp',
    port      => 80,
    cidr      => '0.0.0.0/0',
  },{
    security_group => 'other-security-group',
  }],
  tags        => {
    tag_name  => 'value',
  },
}
```

**ロードバランサのセットアップ**

``` puppet
elb_loadbalancer { 'name-of-load-balancer':
  ensure                  => present,
  region                  => 'us-east-1',
  availability_zones      => ['us-east-1a', 'us-east-1b'],
  instances               => ['name-of-instance', 'another-instance'],
  security_groups         => ['name-of-security-group'],
  listeners               => [
    {
      protocol              => 'HTTP',
      load_balancer_port    => 80,
      instance_protocol     => 'HTTP',
      instance_port         => 80,
    },{
      protocol              => 'HTTPS',
      load_balancer_port    => 443,
      instance_protocol     => 'HTTPS',
      instance_port         => 8080,
      ssl_certificate_id    => 'arn:aws:iam::123456789000:server-certificate/yourcert.com',
      policies              =>  [
        {
          'policy_type'       => 'SSLNegotiationPolicyType',
          'policy_attributes' => {
            'Protocol-TLSv1.1' => false,
            'Protocol-TLSv1.2' => true,
          }
        }
      ]
    }
  ],
  health_check            => {
    'healthy_threshold'   => '10',
    'interval'            => '30',
    'target'              => 'HTTP:80/health_check',
    'timeout'             => '5',
    'unhealthy_threshold' => '2'
  },
  tags                    => {
    tag_name              => 'value',
  },
}
```

これらのリソースのいずれかを破壊するには、`ensure => absent`と設定します。

### スタックの作成

では、ロードバランサー、インスタンス、セキュリティグループを使用した単純なスタックを作成してみましょう。

```
                          WWW
                           +
                           |
          +----------------|-----------------+
          |     +----------v-----------+     |
    lb-sg |     |         lb-1         |     |
          |     +----+------------+----+     |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+  +----v----+     |
          |     |         |  |         |     |
   web-sg |     |  web-1  |  |  web-2  |     |
          |     |         |  |         |     |
          |     +----+----+  +----+----+     |
          +----------|------------|----------+
          +----------|------------|----------+
          |     +----v----+       |          |
          |     |         |       |          |
    db-sg |     |  db-1   <-------+          |
          |     |         |                  |
          |     +---------+                  |
          +----------------------------------+
```

このスタックを作成するためのコードは、このモジュールのtestsディレクトリに用意されています。Puppetでこのコードを実行するには次のコマンドを実行します。

``` bash
puppet apply tests/create.pp --test
```

モジュールをインストールせずにこのディレクトリから試すには、次のコマンドを実行します。

```bash
puppet apply tests/create.pp --modulepath ../ --test
```

上記のコマンドで作成されたリソースを破壊するには、次のコマンドを実行します。

```bash
puppet apply tests/destroy.pp --test
```

### コマンド行からのリソースの管理

モジュールには基本的な`puppet resource`機能が含まれているため、ユーザがコマンド行からAWSリソースを管理できます。

たとえば、次のコマンドを使用するとすべてのセキュリティグループをリストできます。

```bash
puppet resource ec2_securitygroup
```

新しいリソースを作成することもできます。

``` bash
puppet resource ec2_securitygroup test-group ensure=present description="test description" region=us-east-1
```

さらにこれらを破壊する操作もすべてコマンド行から行えます。

``` bash
puppet resource ec2_securitygroup test-group ensure=absent region=sa-east-1
```


### AWSインフラストラクチャの管理

awsモジュールを使用すると、AWSリソースの追跡、VPC内でのグループの自動スケーリング機能の起動、単体テストの実行などさまざまな処理を行えます。モジュールの[examples](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples)ディレクトリにはさまざまな使用例が格納されており、awsモジュールの機能を確認できます。

* [Puppet Enterprise](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/puppet-enterprise/)：AWSモジュールを使用して小さなPuppet Enterpriseクラスタを起動します。
* [Managing DNS](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/manage-dns/)：Puppetを使用してAmazon Route53にあるDNSレコードを管理します。
* [Data Driven Manifests](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/data-driven-manifests/)：データ構造に基づいてリソースを自動的に生成します。
* [Hiera Example](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/hiera-example/)：リージョンやHieraのAMIのIDなど共通の情報を保存します。
* [Infrastructure as YAML](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/yaml-infrastructure-definition/)：YAMLを使用してインフラストラクチャスタック全体を記述し、`create_resources`とHieraを使用してユーザ独自のインフラストラクチャを構築します。
* [Auditing Resources](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/audit-security-groups/)：AWSリソースの変更を追跡したり、他のツールと連携動作します。
* [Unit Testing](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/unit-testing)：Puppetでrspec-puppetなどのテストツールを使用してAWSコードをテストします。
* [Virtual Private Cloud](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/vpc-example)：Puppet DSLを使用してAWS VPC環境を管理します。
* [Using IAM permissions](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/iam-profile)：IAMプロファイルを使用してモジュールに必要なAPIアクセス権を制御します。
* [Elastic IP Addresses](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/elastic-ip-addresses/)：Puppetの管理対象であるインスタンスに、既存の固定グローバルIPアドレスを割り当てます。
* [Create your own abstractions](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/create-your-own-abstractions/)：Puppetで定義されているタイプを使用して、ユーザのインフラストラクチャをさらに良い形にモデル化します。
* [Distribute instances across availability zones](https://github.com/puppetlabs/puppetlabs-aws/tree/master/examples/distribute-across-az/)：futureパーサとstdlib関数を使用して、さまざまな可用性ゾーン上で負荷分散された状態でインスタンスを起動します。

## 参考

### タイプ

* `cloudformation_stack`：CloudFormationスタックを作成、更新、破壊します。
* `cloudfront_distribution`：CloudFrontディストリビューションをセットアップします。
* `ec2_instance`：EC2インスタンスをセットアップします。
* `ec2_securitygroup`：EC2セキュリティグループをセットアップします。
* `ec2_volume`：EC2 EBSボリュームをセットアップします。
* `elb_loadbalancer`：ELBロードバランサをセットアップします。
* `cloudwatch_alarm`：Cloudwatchアラームをセットアップします。
* `ec2_autoscalinggroup`：EC2自動スケーリンググループをセットアップします。
* `ec2_elastic_ip`：固定グローバルIPとその関連付けをセットアップします。
* `ec2_launchconfiguration`：自動スケーリングをサポートするようEC2起動設定をセットアップします。
* `ec2_scalingpolicy`：EC2のスケーリングポリシーをセットアップします。
* `ec2_vpc`：AWS VPCをセットアップします。
* `ec2_vpc_customer_gateway`：AWS VPCカスタマーゲートウェイをセットアップします。
* `ec2_vpc_dhcp_options`：DHCPオプションAWS VPCをセットアップします。
* `ec2_vpc_internet_gateway`：EC2 VPCインターネットゲートウェイをセットアップします。
* `ec2_vpc_routetable`：VPCルートテーブルをセットアップします。
* `ec2_vpc_subnet`：VPCサブネットをセットアップします。
* `ec2_vpc_vpn`：AWS仮想プライベートネットワークをセットアップします。
* `ec2_vpc_vpn_gateway`：VPNゲートウェイをセットアップします。
* `ecs_cluster`：Ec2 Container Serviceクラスタを管理します。
* `ecs_service`：Ec2 Container Serviceサービスを管理します。
* `ecs_task_definition`：Ec2 Container Serviceのタスク定義を管理します。
* `iam_group`：IAMグループとそのメンバーシップを管理します。
* `iam_instance_profile`：IAMインスタンスのプロファイルを管理します。
* `iam_policy`：IAMの「管理」ポリシーを管理します。
* `iam_policy_attachment`：IAMの「管理」ポリシーの割り当てを管理します。
* `iam_role`：IAMの役割を管理します。
* `iam_user`：IAMのユーザを管理します。
* `kms`: KMSのキーとそのポリシーを管理します。
* `rds_db_parameter_group`：DBパラメータグループに読み込みアクセスを許可します。
* `rds_db_securitygroup`：RDS DBセキュリティグループをセットアップします。
* `rds_db_subnet_group`：RDS DBサブネットグループをセットアップします。
* `rds_instance`：RDS Databaseインスタンスをセットアップします。
* `route53_a_record`：Route53 DNSレコードをセットアップします。
* `route53_aaaa_record`：Route53 DNS AAAAレコードをセットアップします。
* `route53_cname_record`：Route53 CNAMEレコードをセットアップします。
* `route53_mx_record`：Route53 MXレコードをセットアップします。
* `route53_ns_record`：Route53 DNSレコードをセットアップします。
* `route53_ptr_record`：Route53 PTRレコードをセットアップします。
* `route53_spf_record`：Route53 SPFレコードをセットアップします。
* `route53_srv_record`：Route53 SRVレコードをセットアップします。
* `route53_txt_record`：Route53 TXTレコードをセットアップします。
* `route53_zone`：Route53 DNSゾーンをセットアップします。
* `s3_bucket`：S3バケットをセットアップします。
* `sqs_queue`：SQSキューをセットアップします。

### パラメータ

#### タイプ：cloudformation_stack

##### `capabilities`

オプション。 

スタック機能のリスト。

有効な値：'CAPABILITY_IAM'、'CAPABILITY_NAMED_IAM'、空のリスト、または無指定。

##### `change_set_id`

読み込み専用。

スタックの一意の識別子。

##### `creation_time`

読み込み専用。

スタックが作成された時刻。

##### `description`

読み込み専用。

スタックに関連付けられたクラウド構造テンプレートに示されているユーザが定義した記述。

##### `disable_rollback`

オプション。 

スタック作成失敗時のロールバックを無効化を設定。 

有効な値：`true`、`false`。

##### `ensure`

必須。 

スタックに対するensureの値。

'present'の場合、スタックは作成されますが更新は適用されません。

'updated'の場合は、スタックが作成されすべての更新が適用されます。

absent'の場合は、スタックが削除されます。

有効な値：'present'、'updated'、'absent'。

##### `id`

読み込み専用。

スタックの一意のID。

##### `last_updated_time`
読み込み専用。

スタックが最後に更新された時刻。

##### `name`

必須。
 
スタックの名前。

##### `notification_arns`

オプション。
 
スタックに関連するイベントが公開されるSNSトピックARNのリスト。

##### `on_failure`

オプション。 

スタック作成失敗時の対応を決定します。

'on_failure'または'disable_rollback'を指定できますが、両方を指定することはできません。

有効な値：'DO_NOTHING'、'ROLLBACK'、'DELETE'。

##### `outputs`

読み込み専用。

スタック出力のハッシュ。

##### `parameters`

オプション。

入力パラメータのハッシュ。

##### `policy_body`

オプション。 

スタックポリシーの内容が格納されている構造体。 

詳細は、『AWS CloudFormationユーザガイド』の「スタックのリソースが更新されないようにする」を参照してください。 

`policy_body`または`policy_url`のいずれかのパラメータを指定できますが、両方を指定することはできません。

##### `policy_url`

オプション。

スタックポリシーが格納されているファイルの場所。URLは、スタックと同じリージョン内のS3バケットに格納されているポリシー(最大サイズ16KB)を指していなければなりません。 

`policy_body`または`policy_url`のいずれかのパラメータを指定できますが、両方を指定することはできません。

##### `region`

必須。
 
スタックを起動するリージョン。

##### `resource_types`

オプション。

このスタックを操作するためのアクセス権が自分に与えられているリソースタイプのリスト。

##### `role_arn`

オプション。 

スタックに関連付けられたAWSの役割Identity and Access Management(IAM)のAmazonリソース名(ARN)。

##### `status`

読み込み専用。

スタックのステータス。

有効な値：'CREATE_IN_PROGRESS'、'CREATE_FAILED'、'CREATE_COMPLETE'、'ROLLBACK_IN_PROGRESS'、'ROLLBACK_FAILED'、'ROLLBACK_COMPLETE'、'DELETE_IN_PROGRESS'、'DELETE_FAILED'、'DELETE_COMPLETE'、'UPDATE_IN_PROGRESS'、'UPDATE_COMPLETE_CLEANUP_IN_PROGRESS'、'UPDATE_COMPLETE'、'UPDATE_ROLLBACK_IN_PROGRESS'、'UPDATE_ROLLBACK_FAILED'、'UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS'、'UPDATE_ROLLBACK_COMPLETE'、'REVIEW_IN_PROGRESS'。

##### `tags`

オプション。

インスタンスのタグ。

##### `template_body`

オプション。 

テンプレートの内容が含まれている構造体。長さは1バイト～51,200バイト。 

詳細は、『AWS CloudFormationユーザガイド』の「テンプレートの分析」を参照してください。

##### `template_url`

オプション。 

テンプレートの内容が含まれているファイルの場所。URLは、Amazon S3バケット内のテンプレート(最大サイズ460,800バイト)を指していなければなりません。 

詳細は、『AWS CloudFormationユーザガイド』の「テンプレートの分析」を参照してください。

##### `timeout_in_minutes`

オプション。 

スタック作成完了までの制限時間。

#### タイプ：cloudfront_distribution

##### `ensure`

リソースの基本的な状態を指定します。 

有効な値：'present'、'absent'。

##### `arn`

読み込み専用。

AWSで生成されたディストリビューションのARN。

##### `id`

読み込み専用。

AWSで生成されたディストリビューションのID。

##### `status`

読み込み専用。

AWSで報告されたディストリビューションのステータス。

##### `comment`

オプション。

ディストリビューションに対するコメント。

##### `enabled`

オプション。

ディストリビューションの有効化を設定。

##### `price_class`

オプション。 

ディストリビューションの価格クラス。

有効な値：'all'、100、200。

デフォルト値：'all'。

使用可能な値は1つのみ。

##### `origins`

必須。
 
少なくとも1つのオリジンを含む配列。各オリジンは、以下のキーを含むハッシュです。

* `type` — 

*必須。* 

オリジンのタイプ。'S3'はまだサポートされていません。

有効な値：'custom'。

* `id` — 

*必須。* 

オリジンID。ディストリビューション内で一意でなければなりません。キャッシングルールのオリジンの特定に使用されます。
* `domain_name` — 

*必須。* 

オリジンのドメイン名。

* `path` —

*オプション。* 

オリジンのパス。既定ではパスがありません。

* `http_port` — 

*カスタムオリジンの場合は必須。* 

オリジンがHTTP接続をリッスンしているポート。

* `https_port` — 

*カスタムオリジンの場合は必須。* 

オリジンがHTTPS接続をリッスンしているポート。

* `protocol_policy` — 

*カスタムオリジンの場合は必須。* 

オリジンに使用可能なプロトコル。

使用可能な値は1つのみ。

有効な値：'http-only'、'https-only'、'match-viewer'。

* `protocols` — 

*カスタムオリジンの場合は必須。* 

オリジンに使用可能なSSLとTLSのバージョンの配列。 

少なくとも1つの値を使用可能。

有効な値：'SSLv3'、'TLSv1'、'TLSv1.1'、'TLSv1.2'。

##### `tags`

オプション。
 
ディストリビューションのタグ。 

タグをkey => valueハッシュで指定できます。 

'Name'タグは除外されます。

#### タイプ：ec2_instance

##### `ensure`

リソースの基本的な状態を指定します。 

有効な値：'present'、'absent'、'running'、'stopped'。

##### `name`

必須。
 
インスタンスの名前。AWSのNameタグの値です。

##### `security_groups`

オプション。 

インスタンスを関連付けるセキュリティグループ。 

セキュリティグループ名の配列を使用できます。

##### `tags`

オプション。 

インスタンスのタグ。 

タグをkey => valueハッシュで指定できます。

##### `user_data`

オプション。 

新しいインスタンス上で実行するユーザデータスクリプト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `key_name`

このインスタンスに関連付けられたキーペアの名前。インスタンスを起動するリージョンにアップロード済みの存在するキーペアでなければなりません。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `monitoring`

オプション。 

このインスタンスのモニタリングの有効化を設定。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：`true`、`false`。 

デフォルト値：`false`。

##### `region`

必須。
 
インスタンスを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `image_id`

必須。
 
インスタンスに使用するイメージID。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

[Amazonマシンイメージ(AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html)を参照。

##### `availability_zone`

オプション。 

インスタンスを配置するアベイラビリティゾーン。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：
 
[AWSのリージョンとアベイラビリティゾーン](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)を参照。

##### `instance_type`

必須。
 
インスタンスに使用するタイプ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

使用可能なタイプについては、[Amazon EC2インスタンス](http://aws.amazon.com/ec2/instance-types/)を参照。

##### `tenancy`

オプション。 

専用インスタンスは、単一のカスタマー専用のハードウェア上の仮想プライベートクラウド(VPC)内で動作するAmazon EC2インスタンスです。 

有効な値：'dedicated'、'default'。

デフォルト値：'default'。

##### `private_ip_address`

オプション。 

インスタンスのプライベートIPアドレス。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：

有効なIPv4アドレス。

##### `associate_public_ip_address`

オプション。 

VPC内のパブリックインターフェイス割り当てを設定。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：`true`、`false`。 

デフォルト値：`false`。

##### `subnet`

オプション。 

インスタンスをアタッチするVPCサブネット。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

サブネット名(サブネットのNameタグの値)を使用できます。Puppetでサブネットを記述している場合、この値はリソース名です。

##### `ebs_optimized`

オプション。 

インスタンス用に最適化されたストレージの使用を設定。  

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：`true`、`false`。 

デフォルト値：`false`。

##### `instance_initiated_shutdown_behavior`

オプション。 

インスタンスからシャットダウンを開始するときに、インスタンスの停止または終了を設定。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：'stop'、'terminate'。 

デフォルト値：'stop'。

##### `block_devices`

オプション。 

インスタンスに関連付けるブロックデバイスのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

device name'、'volume size'、'delete on termination flag'、'volume type'が以下のように指定されたハッシュの配列を使用できます。

``` puppet
block_devices => [
  {
    device_name           => '/dev/sda1',
    volume_size           => 8,
    delete_on_termination => 'true',
    volume_type          => 'gp2',
  }
]
```

``` puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    snapshot_id => 'snap-29a6ca13',
  }
]
```

##### `instance_id`

読み込み専用。

AWSで生成されたインスタンスのID。 

##### `hypervisor`

読み込み専用。

インスタンスを実行中のハイパーバイザのタイプ。

##### `virtualization_type`

読み込み専用。

インスタンスの下層の仮想化。

##### `public_ip_address`

読み込み専用。

インスタンスのパブリックIPアドレス。

##### `private_dns_name`

読み込み専用。

インスタンスの内部DNS名。

##### `public_dns_name`

読み込み専用。

インスタンスの公開DNS名。

##### `kernel_id`

読み込み専用。

インスタンスが使用中のカーネルのID。

##### `iam_instance_profile_name`

インスタンスに関連付けるためにユーザが定義したIAMプロファイル名。

##### `iam_instance_profile_arn`

関連付けられたIAMプロファイルのAmazonリソース名。

##### `interfaces`

読み込み専用。

AWSで生成されたインスタンス用のインターフェイスハッシュ。

#### タイプ：ec2_securitygroup

##### `name`

必須。 

セキュリティグループの名前。AWSのNameタグの値です。

##### `region`

必須。
 
セキュリティグループを起動するリージョン。 

有効な値： 

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `ingress`

オプション。 

イングレストラフィックに関するルール。 

配列を使用できます。

##### `id`

読み込み専用。
 
セキュリティグループを一意に特定する既存のリソースから列挙された一意の文字列。

##### `tags`

オプション。 

セキュリティグループ用のタグ。 

タグをkey => valueハッシュで指定できます。

##### `description`

必須。
 
グループに関する簡単な説明。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `vpc`

オプション。

グループを関連付けるべきVPC。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

VPCのNameタグの値を使用できます。

#### タイプ：elb_loadbalancer

##### `name`

必須。
 
ロードバランサの名前。AWSのNameタグの値です。

##### `region`

必須。
 
ロードバランサを起動するリージョン。 

有効な値：
 
[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `listeners`

必須。
 
ロードバランサがリッスンするポートとプロトコル。  

以下の値の配列を使用できます。

  * protocol
  * load_balancer_port
  * instance_protocol
  * instance_port
  * ssl_certificate_id(プロトコルがHTTPSの場合に必要)
  * policy_names(HTTPS用のポリシー名文字列の配列オプション)

##### `health_check`

バックエンドインスタンスの正常性の判定に使用されるELBヘルスチェックの設定。  

以下のキーを含むハッシュを使用できます。

  * healthy_threshold
  * interval
  * target
  * timeout
  * unhealthy_threshold

##### `tags`

オプション。

ロードバランサ用のタグ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

タグをkey => valueハッシュで指定できます。

##### `subnets`

オプション。

ロードバランサを起動するサブネット。 

サブネット名(サブネットのNameタグ)の配列を使用できます。 'availability_zones'または'subnets'のうち1つを設定できます。

##### `security_groups`

オプション。

ロードバランサーに関連付けるセキュリティグループ(VPCのみ)。 

セキュリティグループ名(セキュリティグループのNameタグ)の配列を使用できます。

##### `availability_zones`

オプション。

ロードバランサーを起動するアベイラビリティゾーン。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

アベイラビリティゾーンコードの配列を使用できます。 

有効な値：
 
[AWSのリージョンとアベイラビリティゾーン](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)を参照。

##### `instances`

オプション。

ロードバランサーに関連付けるインスタンス。 

有効な値： 

名前(インスタンスのNameタグ)の配列を使用できます。

##### `scheme`

オプション。

ロードバランサを内部用または公開用に設定。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：'internal'、'internet-facing'。 

デフォルト値：'internet-facing'。ロードバランサが公開されます。

#### タイプ：ec2_volume

##### `name`

必須。

ボリュームの名前。

##### `region`

必須。
 
ボリュームを作成するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `size`

条件により異なる。

EBSボリュームのサイズはGB単位です。スナップショットからリストアする場合、このパラメータは不要です。

##### `iops`

オプション。

プロビジョニング済みIOP SSDボリュームの場合にのみ有効。ボリュームのプロビジョニングのための1秒当たりのI/O動作回数(IOPS)。最高レートは50 IOPS/GiB。

##### `availability_zone`

必須。
 
ボリュームを作成するアベイラビリティゾーン。 

アベイラビリティゾーンコードの配列を使用できます。 

有効な値：
 
[AWSのリージョンとアベイラビリティゾーン](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)を参照。

##### `volume_type`

必須。

ボリュームのタイプ。汎用SSDの場合はgp2、プロビジョニング済みIOP SSDの場合はio1、スループットが最適化されたHDDの場合はst1、コールドHDDの場合はsc1、磁気ボリュームの場合はstandardになります。

##### `encrypted`

オプション。

ボリュームの暗号化を指定します。暗号化されたAmazon EBSボリュームは、Amazon EBS暗号化をサポートするインスタンスのみにアタッチできます。暗号化されたスナップショットから作成されたボリュームは自動的に暗号化されます。暗号化されていないスナップショットから暗号化されたボリュームを作成する方法はなく、暗号化されたスナップショットから暗号化されていないボリュームを作成することもできません。

##### `kms_key_id`

オプション。

暗号化されたボリュームを作成する際に使用するAWSキーマネジメントサービス(AWS KMS)のカスタマーマスターキー(CMK)の完全なARN。このパラメータが必要なのはデフォルトでないCMKを使用する場合だけです。このパラメータが指定されていない場合は、EBS用のデフォルトのCMKが使用されます。

##### `snapshot_id`

オプション。

ボリュームの作成元のスナップショット。

#### タイプ：cloudwatch_alarm

##### `name`

必須。
 
アラームの名前。AWSのNameタグの値です。

##### `metric`

必須。

追跡するメトリクスの名前。

##### `namespace`

必須。

追跡するメトリクスのネームスペース。

##### `statistic`

必須。

追跡するメトリクスの統計。

##### `period`

必須。

アラームチェックの周期、すなわちアラームチェックを実行する頻度。

##### `evaluation_periods`

必須。

アラームの確認に使用するチェック回数。

##### `threshold`

必須。

アラームのトリガに使用するしきい値。

##### `comparison_operator`

必須。

メトリクスのテストに使用する演算子。

##### `region`

必須。

インスタンスを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `dimensions`

オプション。

アラームのフィルタ処理に使用するディメンション。 

EC2のディメンションの詳細は、AWSのドキュメント[ディメンションとメトリクス](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/ec2-metricscollected.html)を参照。

##### `alarm_actions`

オプション。

アラームがトリガされたときにトリガすべきアクション。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

現在、このパラメータでサポートされるのは名前の付いたスケーリングポリシーだけです。

#### タイプ：ec2_autoscalinggroup

##### `name`
必須。

自動スケーリンググループの名前。AWSのNameタグの値です。

##### `min_size`

必須。

グループに含まれるインスタンス数の最小値。

##### `max_size`

必須。

グループに含まれるインスタンス数の最大値。

##### `desired_capacity`

オプション。

グループで動作していなければならないEC2インスタンスの数。この値はグループに含まれるインスタンス数の最小値以上かつ最大値以下でなければなりません。 

デフォルト値：`min_size`。

##### `default_cooldown`

オプション。

1つのスケーリングアクティビティが完了してから別のスケーリングアクティビティが起動できるまでの時間(秒)。

##### `health_check_type`

オプション。

ヘルスチェックに使用するサービス。 

有効な値：'EC2'、'ELB'。

##### `health_check_grace_period`

オプション。

EC2インスタンスのヘルスチェック開始までの、自動スケーリングの待ち時間(秒)。この期間中に失敗したインスタンスのヘルスチェックは無視されます。 

デフォルト値：300。ELBヘルスチェックを追加する場合はこのパラメータが必須です。

##### `new_instances_protected_from_scale_in`

オプション。

スケールインする際に、新しく起動されたインスタンスを自動スケーリングによる終了から保護するかどうかを示します。 

デフォルト値：`true`。

##### `region`

必須。

インスタンスを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `launch_configuration`

必須。

グループに使用する起動設定の名前。AWSのNameタグの値です。

##### `availability_zones`

必須。

インスタンスを起動するアベイラビリティゾーン。 

アベイラビリティゾーンコードの配列を使用できます。 

有効な値：

[AWSのリージョンとアベイラビリティゾーン](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)を参照。

##### `load_balancers`

オプション。

この自動スケーリンググループにアタッチすべきロードバランサ名のリスト。

##### `target_groups`

オプション。

この自動スケーリンググループにアタッチすべきELBv2ターゲットグループ名のリスト。

##### `subnets`

オプション。

自動スケーリンググループに関連付けるサブネット。

##### `termination_policies`

オプション。

インスタンスをスケールインする際に使用する終了ポリシーのリスト。 

有効な値：

[スケールイン時にAuto Scalingがどのインスタンスを終了するかを制御する](http://docs.aws.amazon.com/autoscaling/latest/userguide/as-instance-termination.html)を参照。

##### `tags`

オプション。

自動スケーリンググループに割り当てるタグ。 

タグのハッシュ値以上のキーを使用できます。起動されたインスタンスにタグがプロパゲートされません。

#### タイプ：ec2_elastic_ip

##### `ensure`

リソースの基本的な状態を指定します。 

有効な値：'attached'、'detached'。

##### `name`

必須。

固定グローバルIPのIPアドレス。

有効な値：

既存の固定グローバルIPの有効なIPv4アドレス。

##### `region`

必須。

固定グローバルIPを探すリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `instance`

必須。

固定グローバルIPに関連付けられているインスタンスの名前。AWSのNameタグの値です。

#### タイプ：ec2_launchconfiguration

##### `name`

必須。

起動設定の名前。AWSのNameタグの値です。

##### `security_groups`

必須。

インスタンスに関連付けるセキュリティグループ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

セキュリティグループ名(セキュリティグループのNameタグ)の配列を使用できます。

##### `user_data`

オプション。

新しいインスタンス上で実行するユーザデータスクリプト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `key_name`

オプション。

このインスタンスに関連付けられたキーペアの名前。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `region`

必須。

インスタンスを起動するリージョン。

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `instance_type`

必須。

インスタンスに使用するタイプ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

使用可能なタイプについては、[Amazon EC2インスタンス](http://aws.amazon.com/ec2/instance-types/)を参照。

##### `image_id`

必須。

インスタンスに使用するイメージID。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

[Amazonマシンイメージ(AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html)を参照。

##### `block_device_mappings`

オプション。

インスタンスに関連付けるブロックデバイスのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

以下のように指定されたデバイス名およびボリュームサイズまたはスナップショットIDを含むハッシュの配列を使用できます。

```puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_size  => 8,
  }
]
```

```puppet
block_devices => [
  {
    device_name  => '/dev/sda1',
    volume_type => 'gp2',
  }
]
```

##### `vpc`

オプション。

VPCの指定に関するヒント。複数の異なるVPCに存在する可能性がある'default'のようなあいまいな名前のセキュリティグループの検出に役立ちます。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

#### タイプ：ec2_scalingpolicy

##### `name`

必須。

スケーリングポリシーの名前。AWSのNameタグの値です。

##### `scaling_adjustment`

必須。

グループのサイズを調整する量。

有効な値： 

`adjustment_type`の選択状態により異なります。

ドキュメント[AWSにおける動的なスケーリング](http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/as-scale-based-on-demand.html)を参照。

##### `region`

必須。

ポリシーを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `adjustment_type`

必須。

ポリシーのタイプ。 

ポリシーの調整タイプを指定する文字列を使用できます。 

有効な値：

ドキュメント[調整タイプ](http://docs.aws.amazon.com/AutoScaling/latest/APIReference/API_AdjustmentType.html)を参照。

##### `auto_scaling_group`

必須。

ポリシーをアタッチする自動スケーリンググループの名前。AWSのNameタグの値です。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

#### タイプ：ec2_vpc

##### `name`

必須。

VPCの名前。AWSのNameタグの値です。

##### `region`

オプション。

VPCを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `cidr_block`

オプション。

VPCに使用するIPの範囲。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `dhcp_options`

オプション。

このVPCに使用するDHCPオプションの名前。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `instance_tenancy`

オプション。

このVPCのインスタンスでサポートされるテナンシーオプション。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：'default'、'dedicated'。 

デフォルト値：'default'。

##### `enable_dns_support`

オプション。

VPCに対してDNS解決がサポートされているかどうかを提示。 

有効な値：`true`、`false`。 

デフォルト値：`true`。

##### `enable_dns_hostnames`

オプション。

VPCで起動されたインスタンスがパブリックDNSホスト名を取得するかどうかを提示。 

有効な値：`true`、`false`。 

デフォルト値：`true`。

##### `tags`

オプション。

VPCに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

#### タイプ：ec2_vpc_customer_gateway

##### `name`

必須。

カスタマーゲートウェイの名前。AWSのNameタグの値です。

##### `ip_address`

必須。

カスタマーゲートウェイのIPv4アドレス。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：

有効なIPv4アドレス。

##### `bgp_asn`

必須。

カスタマーゲートウェイ用の自律システム番号。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `tags`

オプション。

カスタマーゲートウェイ用のタグ。 

タグをkey => valueハッシュで指定できます。

##### `region`

オプション。

カスタマーゲートウェイを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `type`

カスタマーゲートウェイのタイプ。現在サポートされている値は'ipsec.1'だけです。

有効な値：'ipsec.1'

デフォルト値：'ipsec.1'

#### タイプ：ec2_vpc_dhcp_options

##### `name`

必須。

DHCPオプションセットの名前。AWSのNameタグの値です。

##### `tags`

オプション。

DHCPオプションセット用のタグ。 

タグをkey => valueハッシュで指定できます。

##### `region`

オプション。

DHCPオプションセットを割り当てるリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `domain_name`

オプション。

DHCPオプション用のドメイン名。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：

配列または1つの有効なドメイン。配列は、Linuxでサポートされるスペースで区切られたリストに変換されます。その他のOSではAmazonの規定どおりに1つしかサポートされない可能性があります。

##### `domain_name_servers`

オプション。

DHCPオプションセットに使用するドメイン名サーバのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

ドメインサーバ名の配列を使用できます。

##### `ntp_servers`

オプション。

DHCPオプションセットに使用するNTPサーバのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

NTPサーバ名の配列を使用できます。

##### `netbios_name_servers`

オプション。

DHCPオプションセットに使用するNetBIOSネームサーバのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

配列を使用できます。

##### `netbios_node_type`

オプション。

NetBIOSノードのタイプ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：1、2、4、8。

#### タイプ：ec2_vpc_internet_gateway

##### `name`

必須。

インターネットゲートウェイの名前。AWSのNameタグの値です。

##### `tags`

オプション。

インターネットゲートウェイに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

##### `region`

オプション。

インターネットゲートウェイを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `vpc`

オプション。

このインターネットゲートウェイを割り当てるVPC。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

#### タイプ：ec2_vpc_routetable

##### `name`

必須。

ルートテーブルの名前。AWSのNameタグの値です。

##### `vpc`

オプション。

ルートテーブルを割り当てるVPC。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `region`

オプション。

ルートテーブルを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `routes`

オプション。

ルーティングテーブル用の個別のルート。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

'destination_cidr_block'と'gateway'の値の配列を使用できます。

```puppet
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
```

##### `tags`

オプション。

ルートテーブルに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

#### タイプ：ec2_vpc_subnet

##### `name`

必須。

サブネットの名前。AWSのNameタグの値です。

##### `vpc`

オプション。

サブネットを割り当てるVPC。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `region`

必須。

サブネットを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `cidr_block`

オプション。

サブネット用のIPアドレスの範囲。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `availability_zone`

オプション。

サブネットを起動するアベイラビリティゾーン。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `tags`

オプション。

サブネットに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

##### `route_table`

サブネットにアタッチするルートテーブル。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `routes`

オプション。

ルーティングテーブル用の個別のルート。 

'destination_cidr_block'と'gateway'の値の配列を使用できます。

##### `id`

読み込み専用。

サブネットを一意に特定する既存のリソースから列挙された一意の文字列。

``` puppet
routes => [
    {
      destination_cidr_block => '10.0.0.0/16',
      gateway                => 'local'
    },{
      destination_cidr_block => '0.0.0.0/0',
      gateway                => 'sample-igw'
    },
  ],
```

##### `tags`

オプション。

ルートテーブルに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

#### タイプ：ec2_vpc_vpn

##### `name`

必須。

VPNの名前。AWSのNameタグの値です。

##### `vpn_gateway`

必須。

VPNにアタッチするVPNゲートウェイ。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `customer_gateway`

必須。

VPNにアタッチするカスタマーゲートウェイ。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `type`

オプション。

VPNゲートウェイのタイプ。現在サポートされている値は'ipsec.1'だけです。

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：'ipsec.1'

デフォルト値：'ipsec.1'

##### `routes`

オプション。

VPN用のルートのリスト。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値： 

右に示すIP範囲：'routes           => ['0.0.0.0/0']'

##### `static_routes`

オプション。
 
スタティックルートの使用を設定。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：`true`、`false`。 

デフォルト値：`true`。

##### `region`

オプション。

VPNを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `tags`

オプション。

VPN用のタグ。 

タグをkey => valueハッシュで指定できます。

#### Type: ec2_vpc_vpn_gateway

##### `name`

必須。

VPNゲートウェイの名前。 

VPNゲートウェイのNameタグの値を使用できます。

##### `tags`

オプション。

VPNゲートウェイに割り当てるタグ。 

タグをkey => valueハッシュで指定できます。

##### `vpc`

必須。

VPNゲートウェイをアタッチするVPN。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `region`

必須。

VPNゲートウェイを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `availability_zone`

オプション。

VPNゲートウェイを起動するアベイラビリティゾーン。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `type`

オプション。
 
VPNゲートウェイのタイプ。現在サポートされている値は'ipsec.1'だけです。

このパラメータは作成時にのみ設定され、更新による影響は受けません。 

有効な値：'ipsec.1'

デフォルト値：'ipsec.1'

#### タイプ：ecs_cluster

ECSクラスタを示すタイプ。

``` puppet
ecs_cluster { 'medium':
  ensure => present,
}
```

##### `name`

必須。

管理するクラスタの名前。

#### タイプ：ecs_service

``` puppet
ecs_service { 'dockerdockerdockerdocker':
  ensure                   => present,
  desired_count            => 1,
  task_definition          => 'dockerdocker',
  cluster                  => 'medium',
  deployment_configuration => {
    'maximum_percent'         => 200,
    'minimum_healthy_percent' => 50
  },
  load_balancers           => [
    {
      'container_name'     => 'mycontainername',
      'container_port'     => '8080',
      'load_balancer_name' => 'name-of-loadbalancer-elb'
    }
}
```

##### `cluster`

必須。

サービスを割り当てるクラスタの名前。

##### `deployment_configuration`

サービスのデプロイ設定。

パーセント値を示す整数値のキー"maximum_percent"、"minimum_healthy_percent"を含むハッシュ。

##### `desired_count`

動作していなければならないサービスの数。

##### `load_balancers`

サービスに割り当てるロードバランサを示すハッシュの配列。

##### `name`

必須。

管理するクラスタの名前。

##### `role`

作成時にクラスタに割り当てる短い役割の名前。

##### `task_definition`

必須。

実行するタスク定義の名前。

#### タイプ：ecs_task_definition

ECSクラスタを示すタイプ。

ECSタスク定義は、複雑な場合があります。既存のコンテナを見つけるには、コンテナ定義に含まれている'name'オプションを使用して、現在の状態とあるべき状態の違いを計算します。'name'オプションを省略することもできますが、その場合はPuppetを実行するたびに新しいコンテナが作成されるため、タスク定義も新しく作成されます。このため、各コンテナ定義内で'name'オプションを定義し、'ecs_task_definition'リソース内で一意の名前を選択することを推奨します。

``` puppet
ecs_task_definition { 'dockerdocker':
  container_definitions => [
    {
      'name'          => 'zleslietesting',
      'cpu'           => '1024',
      'environment'   => {
        'one' => '1',
        'two' => '2',
      },
      'essential'     => 'true',
      'image'         => 'debian:jessie',
      'memory'        => '512',
      'port_mappings' => [
        {
          'container_port' => '8081',
          'host_port'      => '8082',
          'protocol'       => 'tcp',
        },
      ],
    }
  ],
}
```

コンテナオプションを省略する場合はプロバイダの動作についてよく考えることが重要です。

'ecs_task_definition'用のタスクが存在することが分かった場合は、見つかったコンテナオプションが、要求されているオプションとマージされます。その結果、次のような動作が発生します。*Puppetリソース内で定義されていないが発見された実行中のコンテナ内に存在することが分かったコンテナオプションは、実行中のコンテナからコピーされます。*

コンテナからオプションを外したい場合は、以下のいずれかの方法を使用できます。

* コンテナに別の名前を付ける。こうすると、既存のコンテナが必要なコンテナと一致しなくなり、コンテナ全体が置換されます。

* オプションに空白の値を設定する。こうすると、既存のコンテナで定義されている値が、ユーザの指定したオプションに置換されます。文字列オプションの場合は、単純に値を`''`に、または配列値を`[]`にするなどの設定を行います。

##### `container_definitions`

コンテナ定義を示すハッシュの配列。上記の例を参照。

##### `name`

必須。

管理するタスクの名前。

##### `volumes`

タスクを処理するハッシュの配列。ボリュームを示すハッシュは、以下の形式でなければなりません。

``` puppet
{
  name => "StringNameForReference",
  host => {
    source_path => "/some/path",
  },
}
```

##### `replace_image`

コンテナイメージの置換を無効にするブール値。これによりPuppetはコンテナのイメージを作成できますが、一度作成したイメージは修正できなくなります。この機能は、外部CIツールでコンテナのイメージを修正しなければならない環境で、2つの方法でECSを管理できるため便利です。

##### `role`

このタスク内のコンテナに割り当てるべきIAMの役割に対する短い名前または完全なARN。

#### タイプ：iam_group

``` puppet
iam_group { 'root':
  ensure  => present,
  members => [ 'alice', 'bob' ]
}
```

##### `members`

必須。

グループに含めるユーザ名の配列。この配列で指定されていないユーザは除外されます。

#### タイプ：iam_instance_profile

``` puppet
iam_instance_profile { 'my_iam_role':
  ensure  => present,
  roles => [ 'my_iam_role' ],
}
```

##### `ensure`

リソースの基本的な状態を指定します。 

有効な値：'present'、'absent'。

##### `name`

必須。

IAMインスタンスプロファイルの名前。

##### `roles`

オプション。 

このインスタンスプロファイルを関連付けるIAMの役割(場合により複数)。 

複数の役割に対して配列を使用できます。

#### タイプ：iam_policy

[IAMポリシー](http://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)はAWSリソースへのアクセスを管理します。'iam_policy'タイプは、ポリシーのドキュメントの内容のみを管理し、どのエンティティにポリシーがアタッチされるかについては管理しません。'iam_policy'タイプで作成されたポリシーの適用対象の管理については、'iam_policy_attachment'タイプの説明を参照してください。

``` puppet
iam_policy { 'root':
  ensure      => present,
  document    => '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "*",
          "Resource": "*"
        }
      ]
    }',
}
```

'iam_policy'タイプの場合はビルトインポリシーと同じ名前のIAMポリシーを作成できることに注目してください。同じ名前の2つのポリシー(一方はビルトインポリシー、他方はユーザが定義したポリシー)が存在する場合は、ユーザが定義したポリシーが管理用に選択されます。

##### `document`

必須。

JSON形式のIAMポリシーが含まれている文字列。

#### タイプ：iam_policy_attachment

'iam_policy_attachment'リソースは、指定されたポリシーにどのエンティティがアタッチされるかを管理します。ポリシー名が重複する場合の選択については上記の'iam_policy'の説明を参照してください。

これらのリソースに関するポリシーのアタッチを管理するために設定する必要があるパラメータは'users'、'groups'、'roles'だけです。これらのパラメータの1つを未定義のままにしておくと、それらのエンティティへのアタッチは無視されます。1つのエンティティへのアタッチを空白の配列として定義した場合は、指定したポリシーから同様のすべてのエンティティがデタッチされます。

``` puppet
iam_policy_attachment { 'root':
  groups => ['root'],
  users  => [],
}
```

##### `groups`

オプション。

ポリシーにアタッチするグループ名の配列。  

**この配列に記述されていないものはポリシーからデタッチされます。**

##### `users`

オプション。

ポリシーにアタッチするユーザ名の配列。  

**この配列に記述されていないものはポリシーからデタッチされます。**

##### `roles`

オプション。

ポリシーにアタッチする役割名の配列。  

**この配列に記述されていないものはポリシーからデタッチされます。**

#### タイプ：iam_role

'iam_role'タイプはIAMの役割を管理します。  

``` puppet
iam_role { 'devtesting':
  ensure => present,
  policy_document => '[
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]',
}
```

すべてのパラメータは、作成後は読み込み専用になります。

##### `ensure`

リソースの基本的な状態を指定します。 

有効な値：'present'、'absent'。

##### `name`

IAMの役割名

##### `path`

オプション。

役割のパス

##### `policy_document`

どのエンティティにこの役割を割り当て可能かを制御するJSON形式のIAMポリシーが含まれている文字列。

デフォルト値：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

##### `arn`

このIAM役割のAmazonリソース名。

#### タイプ：iam_user

'iam_user'タイプは、IAM内のユーザアカウントを管理します。リソースのタイトルとして必要なのはユーザ名だけです。

``` puppet
iam_user { 'alice':
  ensure => present,
}

iam_user { 'bob':
  ensure => present,
}
```

#### タイプ：kms

'kms'タイプは、KMSキーのライフサイクルとポリシーを管理します。キー自体には、アタッチされた別名のほかには名前の概念がないため、リソース名の前に'alias/'を付けてKMSキーの別名を設定します。

``` puppet
kms { 'somekey':
  ensure => present,
  policy => template('my/policy.json'),
}
```

上記のリソースは、'alias/somekey'とするとどこでも見ることができます。

##### `policy`

指定されたKMSキーを管理するJSON形式のポリシードキュメント。

#### タイプ：rds_db_parameter_group

ただし、現在のところ、このタイプは`puppet resource`でリストできるだけで、Puppetで作成することはできないことに注意してください。

##### `name`

パラメータグループの名前。

##### `region`

パラメータグループがあるリージョン。 

有効な値： 

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `description`

パラメータグループの説明。 

有効な値：文字列。

##### `family`

パラメータグループの互換性があるデータベースファミリの名前('mysql5.1'など)。

#### タイプ：rds_db_securitygroup

##### `name`

必須。

RDS DBセキュリティグループの名前。

##### `description`

RDS DBセキュリティグループの説明。

有効な値：文字列。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `region`

必須。

パラメータグループを起動するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `owner_id`

読み込み専用。

セキュリティグループの所有者の内部AWS ID。

##### `security_groups`

読み込み専用。

RDSセキュリティグループにアタッチされているすべてのEC2セキュリティグループの詳細情報。

##### `ip_ranges`

読み込み専用。

RDSセキュリティグループにアタッチされているすべてのip_rangesの詳細情報と現在のステータス。

#### タイプ：rds_db_subnet_group

##### `name`
*必須* RDS DBサブネットグループの名前。

##### `description`
*必須* RDS DBサブネットグループの説明。

##### `region`
*必須* サブネットグループを作成するリージョン。有効な値については、[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `vpc`
*必須* サブネットグループを作成するVPCの名前。このパラメータはグループ作成時にのみ設定され、更新による影響は受けません。

##### `subnets`
*必須* サブネットグループに含めるサブネット名のリスト。AWSでは2つ以上のサブネットが必要です。

#### タイプ：rds_instance

##### `name`

必須。

RDSインスタンスの名前。

##### `db_name`

通常は、作成されるデータベースの名前。オラクルの場合はSIDになります。MSSQLの場合は設定しないでください。

##### `region`

必須。

パラメータグループを起動するリージョン。

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `db_instance_class`

必須。

データベースインスタンスのサイズ。 

有効な値：

サイズのリストは、[AWSドキュメント](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html)を参照。

##### `availability_zone`

オプション。

インスタンスを配置するアベイラビリティゾーン。

有効な値：

[AWSのリージョンとアベイラビリティゾーン](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html)を参照。

##### `engine`

必須。

使用するデータベースのタイプ。現在のオプションを調べるには、AWS CLIから'rds-describe-db-engine-versions'コマンドを使用します。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `engine_version`

使用するデータベースのバージョン。現在のオプションを調べるには、AWS CLIから'rds-describe-db-engine-versions'コマンドを使用します。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `allocated_storage`

必須。

データベースのサイズ(ギガバイト)。最小サイズの制限が存在することに注意してください。最小サイズは選択されているデータベースエンジンにより異なります。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `license_model`

商用データベース製品のライセンスの種類。現在サポートされている値は、license-included、bring-your-own-license、general-public-licenseです。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `storage_type`

データベースをバックアップするストレージのタイプ。現在サポートされている値は、standard、gp2、io1です。 

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `iops`

最初にインスタンスに割り当てられるプロビジョニング済みIOPSの数(1秒当たりの入/出力動作回数)。  

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `master_username`

データベースインスタンスのマスターユーザの名前。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `master_user_password`

マスターユーザのパスワード。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `multi_az`

ブール値。複数のアベイラビリティゾーン上でインスタンスを実行する場合に必要です。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `db_subnet`

VPC内でRDSインスタンスを起動するための既存のDBサブネットの名前。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `db_security_groups`

インスタンスに関連付けるデータベースセキュリティグループの名前。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `vpc_security_groups`

RDSインスタンスに関連付けるVPCセキュリティグループの名前。また、
下位互換性を確保するためセキュリティグループIDも使用できます。

##### `endpoint`

読み込み専用。

データベースのDNSアドレス。

##### `port`

読み込み専用。

データベースがリッスンしているポート。

##### `skip_final_snapshot`

DBインスタンスが削除される前に最後のDBスナップショットを作成するかどうかを決定します。 

デフォルト値：`false`。

##### `db_parameter_group`

対応するDBパラメータグループの名前。 

有効な値：文字列。

このパラメータは作成時にのみ設定され、更新による影響は受けません。

##### `restore_snapshot`

オプションでスナップショットからのRDS DBの作成をトリガするスナップショットの名前を指定します。

##### `final_db_snapshot_identifier`

インスタンスの終了時に作成されるスナップショットの名前。`skip_final_snapshot`を`false`に設定しなければならないことに注意してください。

##### `backup_retention_period`

バックアップを保持する日数。 

デフォルト値：'30 days'。

##### `rds_tags`

オプション。

インスタンスのタグ。 

タグをkey => valueハッシュで指定できます

#### タイプ：route53

route53タイプは、さまざまなタイプのRoute53レコードをセットアップします。

* `route53_a_record`：Route53 DNSレコードをセットアップします。

* `route53_aaaa_record`：Route53 DNS AAAAレコードをセットアップします。

* `route53_cname_record`：Route53 CNAMEレコードをセットアップします。

* `route53_mx_record`：Route53 MXレコードをセットアップします。

* `route53_ns_record`：Route53 DNSレコードをセットアップします。

* `route53_ptr_record`：Route53 PTRレコードをセットアップします。

* `route53_spf_record`：Route53 SPFレコードをセットアップします。

* `route53_srv_record`：Route53 SRVレコードをセットアップします。

* `route53_txt_record`：Route53 TXTレコードをセットアップします。

* `route53_zone`：Route53 DNSゾーンをセットアップします。

すべてのRoute53レコードタイプで同じパラメータが使用されます。

##### `zone`

必須。

このレコードに関連付けられているゾーン。

##### `name`

必須。

DNSレコードの名前。

##### `ttl`

オプション。

レコードが有効な時間。 

整数を使用できます。

##### `values`

必須。

`alias_target`を使用しない場合。レコードの値。 

配列を使用できます。 

*alias_targetと衝突します。*

##### `name`

必須。

DNSゾーングループの名前。AWSのNameタグの値です。

##### `alias_target`

必須。

この値を使用しない場合はターゲットとなるaliasリソースの名前。 

*値と衝突します。*

##### `alias_target_zone`

必須。

`alias_target`を使用する場合は、alias_targetがあるゾーンのID。

#### タイプ：route53_zone

##### `name`

必須。

DNSゾーンの名前。AWSのNameタグの値です。後に続くドットはオプションです。

##### `id`

読み込み専用。

AWSで生成されたゾーンの英数字ID(前に付いている「/hostedzone/」の部分は除く)。

##### `is_private`

オプション。

ゾーンがプライベートの場合は`True`。プライベートゾーンには1つ以上の対応するVPCが必要です。ゾーンがパブリック(デフォルト)の場合は`False`。作成時に設定され、変更することはできません。

##### `record_count`

読み込み専用。

AWSで報告されたゾーン内のレコードの数。NSレコードとSOAレコードが含まれるため、新規のゾーンには最初は2つのレコードが含まれています。

##### `comment`

オプション。

ゾーンに対するコメント。

##### `tags`

オプション。

ゾーン用のタグ。 

タグをkey => valueハッシュで指定できます。'Name'タグは除外されます。

##### `vpcs`

条件により異なる。

プライベートゾーンの場合は、1つ以上のVPCの配列。各VPCは以下のキーを含むハッシュです。

* `region` — *必須* VPCがあるリージョン
* `vpc` — *必須* VPCの名前。Puppetは、名前がない場合はVPC IDを表示しますが、IDによるVPCの関連付けは管理できないため、名前が付けられている必要があります。

パブリックゾーンの場合は、検証されますが使用されません。

#### タイプ：s3_bucket

##### `name`

必須。

管理するバケットの名前。

##### `policy`

バケットに適用するポリシーのJSON形式の解析可能な文字列。

#### タイプ：sqs_queue

##### `name`

必須。

SQSキューの名前。

##### `region`

必須。

SQSキューを作成するリージョン。 

有効な値：

[AWSのリージョン](http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region)を参照。

##### `delay_seconds`

オプション。

キューに含まれるすべてのメッセージの配信に要する時間(秒) 。 

デフォルト値：0。

##### `message_retention_period`

オプション。

Amazon SQSでメッセージが保持される時間(秒)。 

デフォルト値：345600。

##### `maximum_message_size`

オプション。

Amazon SQSで使用可能なメッセージの上限バイト数。

##### `visibility_timeout`

オプション。

Amazon SQSが他の電力消費コンポーネントのメッセージの受信や処理を停止する時間(秒)。 

デフォルト値：30。

## 制約事項

このモジュールにはRuby 1.9以降が必要であり、Puppetバージョン3.4以降でしかテストされません。

現在、このモジュールのサポート対象はAWS API内の少数のリソースのみです。また、これらのリソースは、'package'、'file'、'user'などの標準的なホストレベルのリソースとは多少位置付けが異なります。 

弊社では、ユーザがこれらの新しいリソースをどのように使用するか、またユーザがモジュールで何をしたいと考えているか、大きな関心を持っています。

また、このモジュールにはRuby 1.9以降が必要であり、Puppetバージョン3.4以降でしかテストされないことにも注意してください。