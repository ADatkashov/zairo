-- What a customer wants to know before booking: where, how to call, what the place is, when it is open.
-- All nullable: existing businesses fill them in later from the Business Admin app.
alter table provider add column address varchar(255);
alter table provider add column phone varchar(50);
alter table provider add column description varchar(2000);
alter table provider add column working_hours varchar(500);
