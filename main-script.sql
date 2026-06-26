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


create or replace procedure create_order(p_customer_id int)
language sql
as $$
    insert into orders (customer_id)
    select customer_id 
    from customers 
    where customer_id = p_customer_id;
$$;

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


create or replace function update_order_total()
returns trigger
language plpgsql as $$
declare v_order_id int;
begin
	select case 
      when TG_OP = 'DELETE' then old.order_id
      else new.order_id
    end into v_order_id;

  	perform calculate_order(v_order_id);
end;
$$;

create trigger trigger_items_change after insert or update or delete on order_items
for each row execute function update_order_total();

create or replace function log_new_order()
returns trigger 
language plpgsql as $$
begin
  insert into order_log (order_id, customer_id, action_type, change_time)
  values(
    new.order_id,
    new.customer_id,
    'create',
    new.order_date
  );
end;
$$;

create trigger trigger_after_created_order after insert on orders
for each row execute function log_new_order();
