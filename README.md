We updated the backend schema for how addon customisation works. Here is everything you need to know and change in the user/customer app.

Database Schema

service_add_ons table (catalog — read only):

id, name, original_price, discount_price, images[]
is_customizable (bool) — whether this addon needs a custom input from the user
customization_input_type (text) — "text" means user types a message to print, "number" means user enters a number (e.g. hours/quantity)
order_add_ons table (junction — written when order is placed):

order_id → orders.id
add_on_id → service_add_ons.id
quantity (int)
price_at_booking (numeric) — lock the price at time of booking
customisation_input (text, nullable) — NEW COLUMN — stores the custom input for THIS specific addon
orders table:

customisation_input (text) — OLD field, was being used as a single shared input for all addons. Do not use this for addon customisation anymore. Each addon now has its own input in order_add_ons.customisation_input.
What needs to change in the user app

1. Addon selection / cart screen
When a user selects an addon where is_customizable = true, show an input field below that addon card:

If customization_input_type == "text" → show a text field with hint like "Enter text to print (e.g. Happy Birthday Rahul)"
If customization_input_type == "number" → show a number input with appropriate hint
Store this input locally per addon until order is placed
2. Order placement (API call)
When inserting rows into order_add_ons, include the customisation_input field for each addon:


INSERT INTO order_add_ons 
  (order_id, add_on_id, quantity, price_at_booking, customisation_input)
VALUES
  (orderId, addonId, qty, price, "Happy Birthday Rahul"),
  (orderId, addonId2, qty, price, null),  -- non-customizable addons = null
  ...
3. Order summary / confirmation screen
After placing the order, for each addon where is_customizable = true and customisation_input is not null, show the custom input the user entered below that addon.

4. Stop writing to orders.customisation_input
Do not save anything to orders.customisation_input for addon customisation anymore. That field is deprecated for this purpose. Each addon's input now lives in order_add_ons.customisation_input.