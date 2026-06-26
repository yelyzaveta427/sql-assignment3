--функція рахує вартість замовлення
create or replace function calculate_order_total(p_order_id int)
returns numeric(10,2) as $$
declare total numeric(10,2);
begin
	select coalesce(sum(quantity * price), 0)
	into total
	from order_items
	where order_id = p_order_id;
	return total;
end;
$$ language plpgsql;

--процедура створює замовлення
create or replace procedure create_order(p_customer_id int)
language sql
as $$
    insert into orders (customer_id)
	values (p_customer_id);
$$;

--процедура додає товар до замовлення
create or replace procedure add_product_to_order(p_order_id int, p_product_id int, p_quantity int)
language plpgsql as $$

begin
	insert into order_items (order_id, product_id, quantity, price)
	select p_order_id, p_product_id, p_quantity, price
	from products where product_id = p_product_id and p_quantity > 0 
	and stock_quantity >= p_quantity; 
	
	update products
	set stock_quantity = stock_quantity - p_quantity
	where product_id = p_product_id and p_quantity > 0 and stock_quantity >= p_quantity;
end;
$$;

--створення функції, що повертає тригер для оновлення вартості замовлення
create or replace function update_order_total()
returns trigger
language plpgsql as $$
declare v_order_id int;
begin
	select coalesce(new.order_id,old.order_id) into v_order_id;

	update orders
	set total_amount = calculate_order_total(v_order_id)
	where order_id = v_order_id;
	return coalesce(new,old);
end;
$$;

--створення самого тригеру, що викликається після вставки товару order_items, оновлення order_items або видалення певного значення в цій таблиці
create trigger trigger_items_change after insert or update or delete on order_items
for each row execute function update_order_total();

--створення функції, що повертає тригер для зберігання моменту створення замовлення 
create or replace function log_new_order()
returns trigger 
language plpgsql as $$
begin
  insert into order_log (order_id, customer_id, action, log_date)
  values(
    new.order_id,
    new.customer_id,
    'create',
    new.order_date
  );
	return new;
end;
$$;
--створення самого тригеру, що викликається після створення нового замовлення
create trigger trigger_after_created_order after insert on orders
for each row execute function log_new_order();

--Тестування
--клієнти можуть бути створені
insert into customers (full_name, email, balance)
values ('Lana Del Rey', 'lana@gmail.com', 20000000.00);
select customer_id, full_name, email, balance from customers;

--товари можуьт бути створені
insert into products (product_name, price, stock_quantity)
values ('Headphones Pro', 100.00, 10);
select product_id, product_name, price, stock_quantity from products;

--можна створити замовлення (створюється для Лани Дел Рей з її ід 5)
call create_order(5);
select order_id, customer_id, order_date, total_amount from orders;

--додається товар до замовлення Лани (ід її замовлення - 4)
call add_product_to_order(4,1,1);
select order_id, product_id, quantity, price from order_items;

--загальна ціна замовлення автоматично оновлюється
select order_id, customer_id, total_amount from orders where order_id = 4;

--перевірка зменшення товару
select product_id, product_name, stock_quantity from products where product_id = 1;
call add_product_to_order(4, 1, 3);
select product_id, product_name, stock_quantity from products where product_id = 1;

--перевірка створення логів нового замовлення
select log_id, order_id, customer_id, action, log_date from order_log;

--Додавання ще товарів до замовлення Лани
call add_product_to_order(4, 2, 1);
call add_product_to_order(4, 3, 2);
call add_product_to_order(4, 4, 2);

explain analyze
--Запит, що виводить усі товари замовлення Лани :)
select 
	p.product_name as "Product name",
	oi.quantity as "Quantity",
	oi.price as "Price for one item",
	(oi.quantity*oi.price) as "Total price for items"
from order_items oi
join products p on oi.product_id = p.product_id where oi.order_id = 4;




