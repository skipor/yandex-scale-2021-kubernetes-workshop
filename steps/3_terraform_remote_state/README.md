# Переносим Terraform state в удалённое хранилище

Есть [множество вариантов удалённого хранилища](https://www.terraform.io/docs/language/settings/index.html) для
Terraform state, один из наиболее удобных и простых - [бакет в Object Storage](https://cloud.yandex.ru/services/storage)
для state и [Yandex Database в режиме Serverless](https://cloud.yandex.ru/services/ydb) для _locks_. Приятным
дополнением будет то, что использование Yandex Database для _locks_ укладывается
в [free-tier](https://cloud.yandex.ru/docs/billing/concepts/serverless-free-tier), т.е. не будет тарифицироваться.

## Создадим необходимые ресурсы

Бакет следует сделать версионированным, чтобы иметь возможность восстановить предыдущее состояние, если оно было
случайно испорчено. Кроме этого, более безопасно будет включить шифрование, чтобы секреты из state не хранились на
дисках незашифрованными. Для шифрования понадобится KMS ключ, который мы привяжем к бакету.

Для управления бакетом, необходимы статический ключ сервисного аккаунта. Мы могли бы переиспользовать сервисный аккаунт
от кластера Managed Kubernetes, но следуя принципу единственной ответственности (single-responsibility principle)
создадим отдельный и выдадим ему минимальные необходимые права.

Ключ сервисного аккаунта нужно безопасно сохранить, чтобы к нему имели доступ нужные члены команды. Мы не можем положить
его в систему контроля версий, т.к. это его скомпрометирует. Удобно, надёжно и безопасно будет сохранить в менеджере
секретов. В Yandex Cloud роль менеджера секретов выполняет [Lockbox](https://cloud.yandex.ru/services/lockbox).

Для state locks создадим Serverless YDB и создадим там таблицу согласно требованиям документации
[Terraform s3 backend state locking](https://www.terraform.io/docs/language/settings/backends/s3.html#dynamodb-state-locking)
.

Создадим файлы описывающие необходимые ресурсы выполнив команду:
```bash
cp steps/3_terraform_remote_state/state_*.tf .
```

Познакомимся с каждым файлом по отдельности.

Бакет с версионированием и шифрованием через KMS ключ:
```bash 
cat state_1_bucket.tf
```

Serverless YDB база данных для state locks: 
```bash 
cat state_2_locks_db.tf
```

Сервисный аккаунт для управления ими:
```bash 
cat state_3_admin_service_account.tf
```

Lockbox секрет с ключом сервисного аккаунта:
```bash 
cat state_4_admin_key_lockbox_secret.tf
```

После этого применим изменения:
```bash
terraform apply
```
Просмотрим план убедившись в том, что все изменения ожидаемые, и введём `yes` подтвердив его выполнение.

За пределами практикума, если ваши Terraform описания разделены по разным каталога, может быть хорошей идеей
переиспользовать эти ресурсы для хранения состояний от нескольких Terraform каталогов. В таком случае правильно было бы
выделить описание ресурсов в отдельный Terraform каталог, а сами ресурсы создать в отдельном каталоге в облаке.

## Укажем Terraform хранить state в Object Storage

Необходимые ресурсы созданы, дальше нужно указать Terraform, чтобы он использовал их как удалённое хранилище.

Сформируем два файла:
- `main.tf` в котором будет указание использовать удалённое хранилище
- `init.sh` который будет
    - получать `secret_key` для доступа к удалённому хранилищу из Lockbox (менеджера секретов)
    - запускать `terraform init`

Для этого запустим скрипт, который получит нужные значения из `state` через `terraform show -json | jq`
и подставит их в шаблон:
```bash
./steps/3_terraform_remote_state/generate_main.tf_and_init.sh.sh

# Посмотрим на результат
tail -n +1 init.sh main.tf
```

# Скопируем state в Object Storage

На всякий случай сделаем резервную копию state файла:
```bash
cp terraform.tfstate ../terraform.tfstate.bak
```

Попросим terraform скопировать локальный state в новое удалённое хранилище:
```bash
./init.sh --force-copy
```

Теперь проверим, что state доступен, и можно иницилизировать Terraform с нуля:
```bash
# Удалим всё локальное состояние Terraform
rm -rf .terraform terraform.tfstate terraform.tfstate.backup
# Инициализируемся заново
./init.sh 
# Проверим, что план пуст - state успешно загружен из удалённого хранилища
terraform plan

echo "Замечание: предупреждение 'Note: Objects have changed outside of Terraform; + labels = {}' недоработка terraform provider :)"
```

Готово!
Теперь любой член команды, которому выдадут нужные IAM права, может начать работу с Terraform выполнив
единожды `./init.sh`.

### [cледующий этап >>>](../4_build_and_push_container_images/README.md)

