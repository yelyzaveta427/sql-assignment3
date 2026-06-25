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