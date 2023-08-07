# Ordering_and_delivery_of_products_SQL
SQL-analysis of an ordering and delivery service

Проект выполнялся на интерактивном тренажере "Симулятор SQL" на платформе KarpovCourses.   
Используемый диалект SQL - PostgreSQL.

Таблицы БД:
user_actions — действия пользователей с заказами.
	user_id		  INT				    id пользователя
	order_id	  INT				    id заказа
	action		  VARCHAR(50)		действие пользователя с заказом; 'create_order' — создание заказа, 'cancel_order' — отмена заказа
	time		    TIMESTAMP		  время совершения действия
	
courier_actions — действия курьеров с заказами.
	courier_id		INT				    id курьера
	order_id		  INT				    id заказа
	action			  VARCHAR(50)		действие курьера с заказом; 'accept_order' — принятие заказа, 'deliver_order' — доставка заказа
	time			    TIMESTAMP		  время совершения действия
	
orders — информация о заказах.
	order_id		    INT			    id заказа 
	creation_time	  TIMESTAMP	  время создания заказа
	product_ids		  integer[]	  список id товаров в заказе
	
users — информация о пользователях.
	user_id 		    INT 			    id пользователя
	birth_date 		  DATE			    дата рождения
	sex 			      VARCHAR(50)		пол
	
couriers — информация о курьерах.
	courier_id 		  INT 			    id курьера
	birth_date 		  DATE			    дата рождения
	sex 			      VARCHAR(50)		пол
	
products — информация о товарах, которые доставляет сервис.
	product_id	 	  INT 			    id продукта
	name 			      VARCHAR(50)		название товара
	price 			    FLOAT(4)		  цена товара

Связи между таблицами:
user_actions.user_id - users.user_id
user_actions.order_id - orders.order_id
orders.product_ids - products.product_id
courier_actions.courier_id - couriers.courier_id
courier_actions.order_id - orders.order_id
courier_actions.time - user_actions.time
