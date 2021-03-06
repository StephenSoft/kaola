# Kaola Restful Api接口协议

## 命名约定

Kaola生成的Api接口是基于http的web接口，URL的命名符合REST规范。其中的表名都是复数形式。

| 操作 | HTTP Method  | URI |
| :--------- | :-----| :---------- |
| 获取列表数据	|	GET	|     /表名(.:format)             |
| 添加新数据	|	POST	|    /表名(.:format)          | 
| 编辑新数据	|	GET	|     /表名/new(.:format)         |
| 编辑已有数据	|	GET	|     /表名/:id/edit(.:format)    |
| 查看已有数据	|	GET	|     /表名/:id(.:format)         |
| 修改已有数据	|	PATCH	|   /表名/:id(.:format)       |
| 修改已有数据	|	PUT	|     /表名/:id(.:format)         |
| 删除已有数据	|	DELETE	|  /表名/:id(.:format)        |
| 批量添加数据	|	POST	|    /表名(.:format)          | 
| 批量修改数据	|	POST	|    /表名/batch_update(.:format)    | 
| 批量删除数据	|	DELETE	|  /表名/:id[,:id](.:format)          |

format目前支持三种：一个是json，这个是提供给前端使用的api接口；一个是xlsx，这个是提供列表数据的Excel文件导出功能；一个是html，这个是后台提供的html显示界面。如果不带format，默认就是html。



## 使用说明
这里所有的使用说明都是以“http://localhost:3000”本地网址的系统为例子，kaola在开发环境下，默认监听在3000端口。
###元数据查询
查看所有的表

	http://localhost:3000/index2.html
	
查看所有的belongs_to(隶属)关系

	http://localhost:3000/belongs.yaml
	
查看所有的many(包含)关系

	http://localhost:3000/many.yaml

### CRUD功能

标准REST接口, 支持两种调用方式: 网页调用和json调用，对应的Content-Type的值分别为 application/x-www-form-urlencoded, application/json。如果json接口调用出错，那么返回的json中包含error字段提供错误的说明信息。


#### 新增接口
模拟x-www-form-urlencoded编码调用：

	curl  -d "tjb_role[id]=1234&tjb_role[role_name]=name" http://localhost:3000/tjb_roles.json

模拟json编码调用：

	curl -X POST --header "Content-Type: application/json" -d @roles.json http://localhost:3000/tjb_roles.json

#### 读取接口

	curl http://localhost:3000/tjb_roles/1234.json

#### 修改接口

	curl  -X PUT -d "tjb_role[role_name]=name2" http://localhost:3000/tjb_roles/1234.json


#### 删除接口

	curl  -X DELETE http://localhost:3000/tjb_roles/1234.json
	
很多浏览器不支持出了GET／POST以外的其它方法，那么可以通过下面的方式调用
	
	curl  -X POST -d "_method=delete" http://localhost:3000/tjb_roles/1234.json
	

### 批量增删改功能

#### 批量新增接口

批量新增接口的url地址和新增接口一样，只是提交的数据格式不一样。
批量新增的话，提交的里层数据是一个数组

	{
	    "表名复数": [{id:id, key:value,...},{}...]
	}

单个新增的话，提交的是一个hash对象

	{
	    "表名单数": {id:id, key:value,...}
	}

单个新增的话，有数据的验证，批量新增接口的是否对字段进行验证未知。

#### 批量修改接口

无法按照批量新增的模式重用修改接口，因为单条数据修改接口“PUT	/表名/:id”和单个id绑定了。所以定义了一个新的批量修改接口的url地址“/表名/batch_update.json”，提交的数据格式和批量新增接口一致。


#### 批量删除接口
批量删除接口的url地址和删除接口一样，只是id的格式不一样。批量删除接口，一次传入多个id，id之间以英文逗号“,”分割。比如

	curl  -X DELETE http://localhost:3000/tjb_roles/1234,5678.json

表示删除id为1234和5678的两条记录。如果删除成功，返回值格式：

		{id:[被删除的id], deleted:true}


#### 通用的批量操作接口
地址"/bulk.json", 在一个接口里完成多个表的数据新增／修改／删除。本接口功能太强，只在其他接口无法满足需求的情况下使用。

{
	'insert': {
	    "表名1复数": [{id:id, key:value,...},{}...],
	    "表名2复数": [{id:id, key:value,...},{}...],
		...
	},
	'update': {
	    "表名1复数": [{id:id, key:value,...},{}...],
	    ...
	},
	'delete': {
	    "表名1复数": [id1,id2,...],
	    "表名2复数": [id1,id2,...],		
	},		
}

TODO：本接口对事务的支持细化，是否支持部分数据提交成功。

### 搜索相关功能
通常的restful api只约定有基本的CRUD功能，没有提供查询功能的规范，所以这里的搜索功能是kaola自定义的一套查询语法，包含查询／分页／排序功能，且所有的功能可自由组合。目前支持的查询条件类型包括：

	s[MRkey]=value
	s[like[MRkey]]=value
	s[date[Rkey]]=value
	s[range[Rkey]]=value
	s[in[Rkey]]=value
	s[cmp[Rkey1(OP)key2]]=
	

key可以包含四种类型：
	基本的单个key，表示数据库的一个字段；
	多字段的Mkey，格式："key1,key2,..."；
	主子表的Rkey，格式：“key1.key2”，兼容单个的key；
	多字段的主子表的组合MRkey
	
其中，多字段的Mkey的格式表示多个字段的or查询，只支持等于和like查询。


如果有多个查询条件，条件之间是逻辑与的关系。

	s[key]=value&s[like[key]]=value

### 列表接口

	curl http://localhost:3000/warehouses.json


### 分页/排序

	curl "http://localhost:3000/warehouses.json?page=1"
	curl "http://localhost:3000/warehouses.json?page=1&per=100"
	curl "http://localhost:3000/warehouses.json?page=1&order=id+desc"

分页参数page支持负数，-1代表最后一页，也就是采用逆序以后的第一页。比如：

	curl "http://localhost:3000/warehouses.json?page=-1&order=created_at+asc"
	
排序order参数支持多个排序条件，以“,”号分隔，比如:

	curl "http://localhost:3000/warehouses.json?page=1&order=warehouse_name+desc,warehouse_category+asc"


### 查询
#### 等于查询

	curl -g "http://localhost:3000/warehouses.json?s[fax]=fax"
	curl -g "http://localhost:3000/warehouses.json?s[fax]=fax&page=1&order=id+desc"

#### Like查询
	curl -g "http://localhost:3000/warehouses.json?s[like[fax]]=f%25"
	curl -g "http://localhost:3000/warehouses.json?s[like[fax]]=f%25&s[fax]=fax&s[old_supplier_id]=abcd"

Like查询的值支持两种特殊字符“%”和“_”，其中“%”表示匹配任意多个字符，“_”匹配任意一个字符。如果Like查询的值不包含特殊字符，则默认前后加上“%”。大部分情况下，查询时不需要加％这样的特殊字符，因为默认查询字符串前后都会加上“%”。除了一种情况：需要占位查询，比如以给定字符串开头或者结尾的查询。

#### 日期查询

	curl -g "http://localhost:3000/warehouses.json?s[date[created_at]]=2016-05-11"
	curl -g "http://localhost:3000/warehouses.json?s[date[created_at]]=2016-05-11,2016-05-12"
	curl -g "http://localhost:3000/warehouses.json?s[date[created_at]]=,2016-05-12"
	curl -g "http://localhost:3000/warehouses.json?s[date[created_at]]=2016-05-12,"

日期查询会把字符串格式的查询参数转换为日期，然后进行范围查询。上面的四个查询分别表示：

	created_at字段的值在2016-05-11的0点，到2016-05-11的24点
	created_at字段的值在2016-05-11的0点，到2016-05-12的24点
	created_at字段的值小于到2016-05-12的24点
	created_at字段的值大于到2016-05-12的0点



#### 数值范围查询
	curl -g "http://localhost:3000/warehouses.json?s[range[id]]=1,5"
	curl -g "http://localhost:3000/warehouses.json?s[range[id]]=,5"
	curl -g "http://localhost:3000/warehouses.json?s[range[id]]=3,"

#### 枚举In查询
	curl -g "http://localhost:3000/warehouses.json?s[in[id]]=1,2,5"

#### 比较Cmp查询
调用方式 s[cmp[key1(OP)key2]]=
比较cmp查询表示两个字段之间的数值关系，支持的OP类型包括："!=","<=",">=","=","<",">"。其中第二个参数可以是常量。
注意，在url中传递时，OP中的等于号“=”需要转义为“%3D”。
注意，本查询最后的等号“=”后面没有值

	curl -g "/tout_products.json?s[cmp[weight%3D1111]]="
	curl -g "/tout_products.json?s[cmp[out_sale_price>lb_sale_price]]="

#### 全文搜索full查询
	curl -g "http://localhost:3000/warehouses.json?s[full[text]]=sometext"	

#### Null查询
给定字段'key'等于null查询：

	s[cmp[key%3Dnull]]=
	
对应的sql查询是:

	key  is null
	
给定字段'key'不等于null查询：

	s[cmp[key!%3Dnull]]=
	
对应的sql查询是:

	key  is not null

#### 多字段OR查询
	curl -g "http://localhost:3000/warehouses.json?s[like[delivery_company,address]]=测试"
	
这个查询的意思是查找所有delivery_company包含‘测试’或者address包含‘测试’的所有仓库。

多个查询条件仍然是AND的关系，比如下面的查询
	curl -g "http://localhost:3000/warehouses.json?s[like[delivery_company,address]]=测试&s[warehouse_code]=11111"

其含义是查找（所有delivery_company包含‘测试’或者address包含‘测试’的仓库）并且 (warehouse_code等于11111)的所有仓库。

## 关联表功能的使用

### 关联表查看
支持在查看一条数据时，自动带出关联的belongs_to的父表的数据。

要自动带出所有的关联子表的数据（仅支持在开发环境下使用），传递“many=1”参数

	http://localhost:3000/warehouses/23dd811b-cd07-4f80-b7e2-62674f400c8e.json?many=1

带出给定的几个关联子表数据：传递参数many=表1[,表2]

	http://118.178.17.98:3000/warehouses/23dd811b-cd07-4f80-b7e2-62674f400c8e.json?many=tso_saleorder_details
	http://localhost:3000/warehouses/23dd811b-cd07-4f80-b7e2-62674f400c8e.json?many=tbe_express_print_templates,tbp_curing_headers

### 关联表的列表查看
带出给定的几个关联子表数据：传递参数many=表1[,表2]

	http://localhost:3000/warehouses.json?many=tbe_express_print_templates,tbp_curing_headers

列表和浏览接口里的many关系数据自动带出功能，默认返回100条数据，所以只支持many集合数据量较少的情况。如果数据量大，且需要排序／分页等需求，建议单独再调用一次列表查询接口。


#### 关联表的加载数量控制
在关联表的列表和单条数据的查询url中都支持控制每条数据下面自动获取的关联数据的数量，传递参数many\_size，默认值是100。

### 关联表保存
支持在一个事务里保存主表和关联的多个子表。
在test/jsontest目录下有一个例子。

	{
		"tjb_role": {
			"id": "57",
			"owner_module": "test",
			"role_name": "测试角色",
			"role_desc": "HELLO1",
			"state": 0,
			"updated_tjb_operator_id": "048e7eb9-c533-40cc-ad39-738d24f0452d",
			"updated_operator_name": "测试"
		},
		"tjb_operator_roles": [{
			"id": "57",
			"tjb_operator_id": "f9f5ae4b-50d6-42e5-b46e-46b0b3a44c50",
			"state": 0,
			"updated_tjb_operator_id": "048e7eb9-c533-40cc-ad39-738d24f0452d",
			"updated_operator_name": "测试"
		}]
	}


	curl -X POST --header "Content-Type: application/json" -d @roles.json http://localhost:3000/tjb_roles.json
	
### 关联表删除
关联表之间如果存在数据库外键约束，单独删除主表的数据是不能成功的。此时就需要把依赖于该主表的所有子表数据也删除。在删除的接口增加一个many参数，用于处理这种情况，传递格式“many=表1[,表2]”，比如：
	
	curl  -X DELETE http://localhost:3000/tjb_roles/1234.json?many=tjb_operator_roles

关联表删除和批量删除是一个接口, 可以一次性删除。比如： /1,2,3,4.json?many=table1s,table2s
代表批量删除“1,2,3,4”四个数据，其中每个数据都级联删除两个子表“table1s,table2s”的所有关联数据。


### 关联表查询
关联表的查询支持所有单表查询的功能，包括等于／Like／日期／数值范围／枚举查询。关联表查询的时候，支持两个方向：获得子表数据且关联的字段在主表，获得主表数据且关联的字段在子表。两个方向的区别在于单复数规则，其url约定如下：

获得子表数据且关联的字段在主表：

	子表复数.json?s[主表单数.字段名]=

获得主表数据且关联的字段在子表：

	主表复数.json?s[子表复数.字段名]=


#### 等于查询

	curl -g "http://localhost:3000/warehouses.json?s[tbc_company.company_name]=测试公司"
	curl -g "http://localhost:3000/warehouses.json?s[tbc_company.company_name]=测试公司&page=1&order=id+desc"

#### Like查询
	curl -g "http://localhost:3000/warehouses.json?s[tbc_company.company_name]=测试%25"

#### 日期查询
	curl -g "http://localhost:3000/warehouses.json?s[date[tbc_company.created_at]]=2016-05-11"
	curl -g "http://localhost:3000/warehouses.json?s[date[tbc_company.created_at]]=2016-05-11,2016-05-12"

#### 数值范围查询
	curl -g "http://localhost:3000/warehouses.json?s[range[tbc_company.id]]=1,5"
	curl -g "http://localhost:3000/warehouses.json?s[range[tbc_company.id]]=,5"
	curl -g "http://localhost:3000/warehouses.json?s[range[tbc_company.id]]=3,"

#### 枚举In查询
	curl -g "http://localhost:3000/warehouses.json?s[in[id]]=1,2,5"

#### Exists查询
主子表增加子表是否为空的exists查询。比如下面的查询表示查询所有的tbp_products，其在tbp_product_mappings表中不存在。主表是tbp_products，子表是tbp_product_mappings，且要求字表存在字段tbp_product_id。
	curl -g "http://localhost:3000/tbp_products.json?s[exists[tbp_product_mappings]]=0"

查询的值只能是0或者1，分表代表子表集合为空或者非空。
	curl -g "http://localhost:3000/tbp_products.json?s[exists[tbp_product_mappings]]=1&count=1"

	
### 树形结构的查询
树形结构最常见的例子有组织结构、产品类别等。为了存储树形结构，要求给定的表有一个指向自己的外键。外键值为空的节点是树的根节点。
有两个参数：depth，表示嵌套的深度，many_size，表示每一层的数量限制。

树形结构功能只针对单条数据的接口提供，返回该条数据下面的嵌套的多层子树数据。

uv_insured_units/1.json?many=uv_insured_units&depth=3&many_size=1


### 查询的Count支持
上面提到的所有列表／查询／分页／关联表查询json接口，都支持查询的同时返回符合记录的条数总数。方式是在url中增加count参数。目前支持两种类型，count=1和count=2，比如：

	curl http://localhost:3000/warehouses.json?count=1

带count=1的json输出的格式：

	{
		"count":数字
		"data":[{字段名:值}]
	}
	
带count=2的json输出的格式：

	{
		"count":数字
	}	
	

如果是不带count的搜索页输出，格式为：

	[{字段名:值}]

### 查询的Index支持
对于一些复杂的sql查询，需要自己指定使用的索引的时候，可以传递index参数来指定索引。比如：

	curl http://localhost:3000/warehouses.json?index=inq_out_product_lb_product_id


### 查询的post支持（Todo）
因为get请求有256字符的长度限制，后续考虑（还未实现）查询参数，也可以通过post的方式提交，比如：

	curl "url" -d '{
	    "s" : {
			field1 : value1,
			"like" : {
				field2 : value2,
				field3 : value3				
			}
		},
		"page" : 1,
		"per" : 100,
		"count" : 1
	}'

	
## 缓存

所有的获取列表数据／查看单个数据的GET请求支持服务器端缓存。缓存是全自动化处理的，新增／修改／删除请求会自动过期涉及到的缓存数据。但是，如果通过其它方式直接修改了数据库而没有通过接口修改数据，那么需要通知接口过期相关的缓存。

#### 过期特定表的缓存

| 方法 | URL |
| :------- | :------- |
| post      | /cache/expire |

| 参数 | 类型  | 必填 | 说明 |
| :------|------- | :------|------- |
| tables | String | 必填 | 需要过期缓存的数据库表，如果多张表则以,号分割 |


#### 过期所有的缓存

| 方法 | URL |
| :------- | :------- |
| post      | /cache/expire\_all |

不需要传参数。

所有的GET请求默认都支持ETAG，当客户端重复请求的时候，如果带上上次请求的ETAG，当服务器端内容无更新的时候，会返回304响应。

## 其它接口

### 直接数据库sql查询

首先ts_sql_infos，定义要查询的sql语句以及动态参数的类型，其中的动态参数传入部分用"?"表示，类型包括s/i/f/d，分别代表字符串／整数／浮点数／日期。多个参数类型，以英文逗号","分割。

查询的url是"/search/:id.json", 参数通过"1=...&2=..."来传递。暂不支持可选参数。

	curl http://localhost:3000/sql/search/3.json?1=5672c997783d1024b4bffa4c&2=%25%25&3=%25YD%25
	

### 数据库存储过程执行
待完善：

	curl http://localhost:3000/sql/exec/
	
### 健康检测接口

	curl http://localhost:3000/sql/heartbeat.json

### 数据批量导入导出

#### Excel导入
	目前支持Excel文件的批量导入。
	Excel文件的格式要求：第一行是要导入的数据的列名或者列的注释名，从第二行开始是要导入的数据。文件后缀是xlsx。 
	
### Excel导出
	目前支持单表数据的Excel导出，文件后缀是xlsx。 列表数据的查询url中，把json更改为xlsx，就可以把查询到的数据导出为excel。比如下面的这些例子：
	
	http://localhost:3000/warehouses.xlsx
	http://localhost:3000/warehouses.xlsx?page=1&per=100
	http://localhost:3000/warehouses.xlsx?s[range[id]]=1,5
	

## 已知的问题

* 单复数表名同时存在，比如存在两张表'table'和'tables'，那么无法区分
* 不支持跨数据库的事务，不支持跨数据库的连接查询
* 主子表数据一次性保存的时候，如果有数据库外键，会导致死锁
	
## 相关文档

* [内部实现原理](./Tech.md)；

