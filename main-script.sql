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

