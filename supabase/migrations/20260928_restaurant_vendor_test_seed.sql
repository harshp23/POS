-- ============================================================================
-- 20260928 — Restaurant Vendor Panel Complete Test Seed Script
-- Restaurant: "Spicy Bistro" (Multi-branch: Delhi CP, Noida 62, Bengaluru)
-- Idempotent & Safe to run: Uses ON CONFLICT DO UPDATE / DO NOTHING
-- ============================================================================

DO $$
DECLARE
  v_org_id uuid := 'e0000000-0000-0000-0000-000000000001';
  v_loc_cp uuid := 'e0000000-0000-0000-0000-000000000011';
  v_loc_noi uuid := 'e0000000-0000-0000-0000-000000000012';
  v_loc_blr uuid := 'e0000000-0000-0000-0000-000000000013';
  v_user_id uuid := 'e0000000-0000-0000-0000-000000000101';
  v_role_admin_id uuid;
  v_cat_main uuid := 'c0000000-0000-0000-0000-000000000001';
  v_cat_start uuid := 'c0000000-0000-0000-0000-000000000002';
  v_cat_bread uuid := 'c0000000-0000-0000-0000-000000000003';
  v_cat_bev uuid := 'c0000000-0000-0000-0000-000000000004';
  v_cat_des uuid := 'c0000000-0000-0000-0000-000000000005';
  v_area_gf uuid := 'a0000000-0000-0000-0000-000000000001';
  v_area_ff uuid := 'a0000000-0000-0000-0000-000000000002';
  v_area_patio uuid := 'a0000000-0000-0000-0000-000000000003';
  v_dish_bc uuid := 'd0000000-0000-0000-0000-000000000001';
  v_dish_pbm uuid := 'd0000000-0000-0000-0000-000000000002';
  v_dish_gbn uuid := 'd0000000-0000-0000-0000-000000000003';
  v_dish_pt uuid := 'd0000000-0000-0000-0000-000000000004';
  v_dish_ml uuid := 'd0000000-0000-0000-0000-000000000005';
  v_dish_gj uuid := 'd0000000-0000-0000-0000-000000000006';
  v_tbl_t1 uuid := 'b0000000-0000-0000-0000-000000000001';
  v_tbl_t2 uuid := 'b0000000-0000-0000-0000-000000000002';
  v_tbl_t3 uuid := 'b0000000-0000-0000-0000-000000000003';
  v_tbl_t4 uuid := 'b0000000-0000-0000-0000-000000000004';
  v_tbl_t5 uuid := 'b0000000-0000-0000-0000-000000000005';
  v_order_1 uuid := 'f0000000-0000-0000-0000-000000000001';
  v_order_2 uuid := 'f0000000-0000-0000-0000-000000000002';
  v_ol_order_1 uuid := 'f0000000-0000-0000-0000-000000000011';
  v_ol_order_2 uuid := 'f0000000-0000-0000-0000-000000000012';
BEGIN
  -- 1. Ensure Roles exist
  SELECT id INTO v_role_admin_id FROM public.roles WHERE slug = 'org_admin' LIMIT 1;
  IF v_role_admin_id IS NULL THEN
    INSERT INTO public.roles (slug, name, is_system)
    VALUES ('org_admin', 'Organization Admin', true)
    RETURNING id INTO v_role_admin_id;
  END IF;

  -- 2. Restaurant Organization
  INSERT INTO public.organizations (id, business_name, email, domain, phone_number, status)
  VALUES (v_org_id, 'Spicy Bistro', 'admin@spicybistro.com', 'Restaurant', '+91 98100 00000', 'Active')
  ON CONFLICT (id) DO UPDATE SET business_name = EXCLUDED.business_name, domain = EXCLUDED.domain, phone_number = EXCLUDED.phone_number, status = 'Active';

  -- 3. Restaurant Branches / Outlets
  INSERT INTO public.org_locations (id, org_id, name, code, type, status, time_zone, currency)
  VALUES 
    (v_loc_cp, v_org_id, 'Delhi - Connaught Place', 'DEL-CP', 'outlet', 'active', 'Asia/Kolkata', 'INR'),
    (v_loc_noi, v_org_id, 'Noida Sector 62', 'NOI-62', 'outlet', 'active', 'Asia/Kolkata', 'INR'),
    (v_loc_blr, v_org_id, 'Bengaluru Indiranagar', 'BLR-IND', 'outlet', 'active', 'Asia/Kolkata', 'INR')
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, code = EXCLUDED.code;

  -- 4. Admin User & Membership
  -- In auth.users if available
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'auth' AND tablename = 'users') THEN
    INSERT INTO auth.users (id, email, encrypted_password, raw_user_meta_data)
    VALUES (v_user_id, 'admin@spicybistro.com', '$2a$10$WdZ/4hZqf4nLz7gVb8/hMeJcZq4kK1gY1v1m2z3y4x5w6v7u8t9s.', '{"first_name":"Asha","last_name":"Admin"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  -- In public.users if available
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    INSERT INTO public.users (id, first_name, last_name, email, phone_number, password, status)
    VALUES (v_user_id, 'Asha', 'Admin', 'admin@spicybistro.com', '+91 98100 00000', '$2a$10$WdZ/4hZqf4nLz7gVb8/hMeJcZq4kK1gY1v1m2z3y4x5w6v7u8t9s.', 'Active')
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
  END IF;

  -- In public.org_users
  INSERT INTO public.org_users (organization_id, user_id, role_id, email, full_name, status)
  VALUES (v_org_id, v_user_id, v_role_admin_id, 'admin@spicybistro.com', 'Asha Admin', 'active')
  ON CONFLICT (organization_id, user_id) DO UPDATE SET status = 'active';

  -- 5. Bill Settings & Counters
  INSERT INTO public.org_bill_settings (organization_id, legal_name, address, gstin, fssai, phone, sgst_pct, cgst_pct, service_charge_pct, round_off_enabled, footer_note)
  VALUES (v_org_id, 'Spicy Bistro Foods Pvt Ltd', 'F-12 Inner Circle, Connaught Place, New Delhi', '07AABCS1234F1Z5', '13320001000234', '+91 98100 00000', 2.5, 2.5, 5.0, true, 'Thank you for dining with Spicy Bistro! Please visit again.')
  ON CONFLICT (organization_id) DO UPDATE SET legal_name = EXCLUDED.legal_name, gstin = EXCLUDED.gstin;

  INSERT INTO public.org_counters (organization_id, kind, value)
  VALUES (v_org_id, 'order_no', 105), (v_org_id, 'kot_no', 84)
  ON CONFLICT (organization_id, kind) DO UPDATE SET value = EXCLUDED.value;

  -- 6. Channel Integrations
  INSERT INTO public.channel_integrations (organization_id, channel, display_name, is_connected, is_accepting, auto_accept, commission_pct)
  VALUES 
    (v_org_id, 'website', 'One Latur Online', true, true, true, 5.0),
    (v_org_id, 'swiggy', 'Swiggy Food', true, true, false, 18.0),
    (v_org_id, 'zomato', 'Zomato Delivery', true, true, false, 18.0),
    (v_org_id, 'qr', 'Dine-In QR Ordering', true, true, true, 0.0)
  ON CONFLICT (organization_id, channel) DO UPDATE SET is_connected = true;

  -- 7. Kitchen Stations
  INSERT INTO public.kitchen_stations (organization_id, key, name, colour, sort_order)
  VALUES 
    (v_org_id, 'curry', 'North Indian Curry Counter', '#EF4444', 1),
    (v_org_id, 'tandoor', 'Tandoor & Breads Station', '#F59E0B', 2),
    (v_org_id, 'beverage', 'Beverage & Bar Counter', '#3B82F6', 3),
    (v_org_id, 'dessert', 'Dessert & Sweet Section', '#10B981', 4)
  ON CONFLICT DO NOTHING;

  -- 8. Menu Categories
  INSERT INTO public.menu_categories (id, organization_id, name, sort_order)
  VALUES 
    (v_cat_main, v_org_id, 'Main Course', 1),
    (v_cat_start, v_org_id, 'Starters', 2),
    (v_cat_bread, v_org_id, 'Breads', 3),
    (v_cat_bev, v_org_id, 'Beverages', 4),
    (v_cat_des, v_org_id, 'Desserts', 5)
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

  -- 9. Menu Items
  INSERT INTO public.menu_items (id, organization_id, category_id, name, sku, price, image_url, is_available, is_recommended, sort_order, station, course, food_type, prep_minutes, description)
  VALUES 
    (v_dish_bc, v_org_id, v_cat_main, 'Spicy Butter Chicken', 'SB-BC-001', 380.00, 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=500', true, true, 1, 'curry', 'eat', 'non_veg', 15, 'Tender boneless chicken roasted in tandoor and simmered in rich makhani butter gravy.'),
    (v_dish_pbm, v_org_id, v_cat_main, 'Paneer Butter Masala', 'SB-PBM-002', 340.00, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=500', true, true, 2, 'curry', 'eat', 'veg', 12, 'Fresh cottage cheese cubes in mildly sweet, velvety tomato-cashew butter sauce.'),
    (v_dish_gbn, v_org_id, v_cat_bread, 'Garlic Butter Naan', 'SB-GBN-003', 60.00, 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500', true, false, 3, 'tandoor', 'eat', 'veg', 6, 'Crisp artisan flatbread brushed with crushed garlic and melted Amul butter.'),
    (v_dish_pt, v_org_id, v_cat_start, 'Paneer Tikka Special', 'SB-PTS-004', 290.00, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=500', true, true, 4, 'tandoor', 'eat', 'veg', 12, 'Marinated cottage cheese char-grilled with bell peppers and onions.'),
    (v_dish_ml, v_org_id, v_cat_bev, 'Mango Lassi', 'SB-ML-006', 180.00, 'https://images.unsplash.com/photo-1553787499-6f9133860278?w=500', true, false, 5, 'beverage', 'drink', 'veg', 4, 'Thick creamy churned yogurt blended with ripe Alphonso mango pulp.'),
    (v_dish_gj, v_org_id, v_cat_des, 'Gulab Jamun (2 pcs)', 'SB-GJ-007', 120.00, 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=500', true, false, 6, 'dessert', 'eat', 'veg', 3, 'Traditional warm milk dumplings soaked in cardamom rose syrup.')
  ON CONFLICT (id) DO UPDATE SET price = EXCLUDED.price, is_available = true;

  -- 10. Dining Areas & Tables (per branch)
  INSERT INTO public.dining_areas (id, organization_id, location_id, name, sort_order)
  VALUES 
    (v_area_gf, v_org_id, v_loc_cp, 'Ground Floor Main', 1),
    (v_area_ff, v_org_id, v_loc_cp, 'First Floor Family', 2),
    (v_area_patio, v_org_id, v_loc_cp, 'Terrace Patio', 3)
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

  INSERT INTO public.dining_tables (id, organization_id, location_id, area_id, label, seats, is_active, sort_order, qr_token)
  VALUES 
    (v_tbl_t1, v_org_id, v_loc_cp, v_area_gf, 'T1', 4, true, 1, 'qr-sb-del-t1'),
    (v_tbl_t2, v_org_id, v_loc_cp, v_area_gf, 'T2', 4, true, 2, 'qr-sb-del-t2'),
    (v_tbl_t3, v_org_id, v_loc_cp, v_area_gf, 'T3', 2, true, 3, 'qr-sb-del-t3'),
    (v_tbl_t4, v_org_id, v_loc_cp, v_area_ff, 'T4', 6, true, 4, 'qr-sb-del-t4'),
    (v_tbl_t5, v_org_id, v_loc_cp, v_area_patio, 'T5', 4, true, 5, 'qr-sb-del-t5')
  ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, seats = EXCLUDED.seats;

  -- 11. Active Orders & Items on Floor
  INSERT INTO public.orders (id, organization_id, location_id, order_no, display_no, channel, status, table_id, customer_name, customer_phone, subtotal, gst_pct, gst_amount, total, discount, payment_method, placed_by, guest_count)
  VALUES 
    (v_order_1, v_org_id, v_loc_cp, 101, 'SB-101', 'dine_in', 'sent_to_kitchen', v_tbl_t2, 'Rohit Sharma', '+91 98112 34567', 800.00, 5.0, 40.00, 840.00, 0, 'upi', 'pos', 3),
    (v_order_2, v_org_id, v_loc_cp, 102, 'SB-102', 'pickup', 'ready', NULL, 'Anita Rao', '+91 98765 12345', 500.00, 5.0, 25.00, 525.00, 0, 'cash', 'pos', 1)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.order_items (order_id, menu_item_id, name, qty, unit_price, status, course, station)
  VALUES 
    (v_order_1, v_dish_bc, 'Spicy Butter Chicken', 1, 380.00, 'preparing', 'eat', 'curry'),
    (v_order_1, v_dish_gbn, 'Garlic Butter Naan', 3, 60.00, 'preparing', 'eat', 'tandoor'),
    (v_order_1, v_dish_ml, 'Mango Lassi', 2, 180.00, 'ready', 'drink', 'beverage'),
    (v_order_2, v_dish_pbm, 'Paneer Butter Masala', 1, 340.00, 'ready', 'eat', 'curry'),
    (v_order_2, v_dish_gbn, 'Garlic Butter Naan', 2, 60.00, 'ready', 'eat', 'tandoor')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.kot_tickets (organization_id, order_id, kot_no, station, status, priority)
  VALUES 
    (v_org_id, v_order_1, 81, 'curry', 'preparing', 'normal'),
    (v_org_id, v_order_1, 82, 'tandoor', 'preparing', 'normal')
  ON CONFLICT DO NOTHING;

  -- 12. One Latur Online Marketplace Orders (ol_orders)
  INSERT INTO public.ol_orders (id, organization_id, status, subtotal, gst, delivery_fee, total, payment_method, payment_status, prep_minutes, eta_minutes, rider_name, rider_phone, customer_hash, delivery_address, items)
  VALUES 
    (v_ol_order_1, v_org_id, 'placed', 440.00, 22.00, 40.00, 502.00, 'upi', 'paid', 25, 45, NULL, NULL, 'cust-priya', '{"name":"Priya Nair","phone":"+91 99887 66554","line1":"Flat 402, Lotus Apts, Latur","city":"Latur"}'::jsonb, '[{"name":"Spicy Butter Chicken","qty":1,"price":380},{"name":"Garlic Butter Naan","qty":1,"price":60}]'::jsonb),
    (v_ol_order_2, v_org_id, 'preparing', 520.00, 26.00, 40.00, 586.00, 'upi', 'paid', 20, 35, 'Sachin Kamble', '+91 97654 32109', 'cust-arjun', '{"name":"Arjun Mehta","phone":"+91 98220 11223","line1":"12 Shivaji Chowk, Latur","city":"Latur"}'::jsonb, '[{"name":"Paneer Butter Masala","qty":1,"price":340},{"name":"Mango Lassi","qty":1,"price":180}]'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.ol_order_items (order_id, name, price, qty, line_total)
  VALUES 
    (v_ol_order_1, 'Spicy Butter Chicken', 380.00, 1, 380.00),
    (v_ol_order_1, 'Garlic Butter Naan', 60.00, 1, 60.00),
    (v_ol_order_2, 'Paneer Butter Masala', 340.00, 1, 340.00),
    (v_ol_order_2, 'Mango Lassi', 180.00, 1, 180.00)
  ON CONFLICT DO NOTHING;

  -- 13. POS Suppliers & Supplier Prices
  INSERT INTO public.pos_suppliers (row_id, organization_id, location_id, id, name, legal_name, category, contact_person, phone, email, gstin, city, rating, payment_terms, active)
  VALUES 
    ('ba000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'SPL-0082', 'ABC Foods', 'ABC Foods Pvt Ltd', 'Dairy & Poultry', 'Vikram Mehta', '+91 98110 22334', 'orders@abcfoods.in', '07AAAAA1111A1Z1', 'New Delhi', 4.6, 'Net 15 Days', true),
    ('ba000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 'SPL-0041', 'Krishna Dairy & Farm', 'Krishna Dairy LLP', 'Dairy & Milk Products', 'Suresh Patel', '+91 98230 11223', 'sales@krishnadairy.com', '27AAKFK4411L1Z5', 'Latur', 4.8, 'Net 7 Days', true),
    ('ba000000-0000-0000-0000-000000000003', v_org_id, v_loc_cp, 'SPL-0057', 'Global Spices & Co', 'Global Spices & Co', 'Spices & Condiments', 'Ramesh Verma', '+91 98765 43210', 'info@globalspices.com', '27AAGFG2231M1Z2', 'Mumbai', 4.5, 'Net 30 Days', true)
  ON CONFLICT (row_id) DO NOTHING;

  INSERT INTO public.pos_supplier_prices (row_id, organization_id, location_id, id, ingredient_name, material_id, emoji, linked_to, supplier_id, unit, last_price, current_price, lowest_week, source, priority, sku_id, approved)
  VALUES 
    ('bb000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'sp-chicken', 'Raw Chicken Breast', 'rm-chicken', '🍗', 'Spicy Butter Chicken', 'SPL-0082', 'kg', 240.0, 225.0, 220.0, 'Weekly Mandi Rate', 'High', 'SKU-CHK-01', true),
    ('bb000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 'sp-paneer', 'Fresh Paneer Block', 'rm-paneer', '🧀', 'Paneer Butter Masala', 'SPL-0041', 'kg', 310.0, 295.0, 290.0, 'Contract Dairy Rate', 'High', 'SKU-PAN-02', true),
    ('bb000000-0000-0000-0000-000000000003', v_org_id, v_loc_cp, 'sp-butter', 'Amul Butter Block', 'rm-butter', '🧈', 'Butter Chicken / Naan', 'SPL-0041', 'kg', 520.0, 510.0, 505.0, 'Distributor Invoice', 'Medium', 'SKU-BUT-03', true)
  ON CONFLICT (row_id) DO NOTHING;

  -- 14. POS Raw Materials / Inventory
  INSERT INTO public.pos_raw_materials (row_id, organization_id, location_id, id, code, name, category, unit, stock_qty, reorder_level, max_capacity, purchase_cost, last_purchase_price, preferred_supplier_id, hsn, emoji, lead_time_days, active)
  VALUES 
    ('bc000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'rm-chicken', 'RM-POU-001', 'Raw Chicken Breast', 'Poultry', 'kg', 45.5, 20.0, 100.0, 225.0, 225.0, 'SPL-0082', '02071400', '🍗', 1, true),
    ('bc000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 'rm-paneer', 'RM-DAI-001', 'Fresh Paneer Block', 'Dairy', 'kg', 32.0, 15.0, 80.0, 295.0, 295.0, 'SPL-0041', '04061000', '🧀', 1, true),
    ('bc000000-0000-0000-0000-000000000003', v_org_id, v_loc_cp, 'rm-butter', 'RM-DAI-002', 'Amul Butter Block', 'Dairy', 'kg', 24.0, 10.0, 60.0, 510.0, 510.0, 'SPL-0041', '04051000', '🧈', 2, true),
    ('bc000000-0000-0000-0000-000000000004', v_org_id, v_loc_cp, 'rm-flour', 'RM-GRO-001', 'Refined Wheat Flour (Maida)', 'Groceries', 'kg', 85.0, 30.0, 200.0, 42.0, 42.0, 'SPL-0082', '11010000', '🌾', 3, true),
    ('bc000000-0000-0000-0000-000000000005', v_org_id, v_loc_cp, 'rm-mango', 'RM-BEV-001', 'Alphonso Mango Pulp', 'Beverages', 'kg', 18.0, 8.0, 50.0, 180.0, 180.0, 'SPL-0082', '20089900', '🥭', 2, true)
  ON CONFLICT (row_id) DO NOTHING;

  -- 15. POS Purchase Orders & PO Lines
  INSERT INTO public.pos_purchase_orders (row_id, organization_id, location_id, number, supplier_id, order_date, expected_delivery, status, created_by, delivery_address, delivery_city, tax_pct, notes)
  VALUES 
    ('bd000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'PO-2026-0042', 'SPL-0082', now() - interval '2 days', now() + interval '1 day', 'Approved', 'Manager Priya', 'Connaught Place Central Kitchen', 'New Delhi', 5.0, 'Urgent restock before weekend'),
    ('bd000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 'PO-2026-0043', 'SPL-0041', now() - interval '1 day', now() + interval '2 days', 'Sent', 'Chef Rahul', 'Connaught Place Central Kitchen', 'New Delhi', 5.0, 'Weekly dairy order')
  ON CONFLICT (row_id) DO NOTHING;

  INSERT INTO public.pos_purchase_order_lines (row_id, organization_id, location_id, id, po_number, material_id, material_name, code, unit, unit_cost, ordered_qty, received_qty, rejected_qty)
  VALUES 
    ('be000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 1, 'PO-2026-0042', 'rm-chicken', 'Raw Chicken Breast', 'RM-POU-001', 'kg', 225.0, 50.0, 50.0, 0),
    ('be000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 2, 'PO-2026-0043', 'rm-paneer', 'Fresh Paneer Block', 'RM-DAI-001', 'kg', 295.0, 30.0, 0, 0)
  ON CONFLICT (row_id) DO NOTHING;

  -- 16. POS Goods Receipts (GRN)
  INSERT INTO public.pos_goods_receipts (row_id, organization_id, location_id, id, po_number, received_at, subtotal, tax, total, notes)
  VALUES 
    ('bf000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'GRN-2026-0038', 'PO-2026-0042', now() - interval '1 day', 11250.00, 562.50, 11812.50, 'All 50kg chicken verified fresh and temperature compliant.')
  ON CONFLICT (row_id) DO NOTHING;

  -- 17. POS Stock Movements
  INSERT INTO public.pos_stock_movements (row_id, organization_id, location_id, id, material_id, qty_delta, reason, reference, unit_cost)
  VALUES 
    ('ca000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 1, 'rm-chicken', 50.0, 'GRN Receipt', 'GRN-2026-0038', 225.0),
    ('ca000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 2, 'rm-chicken', -8.5, 'KOT Preparation', 'KOT-81', 225.0),
    ('ca000000-0000-0000-0000-000000000003', v_org_id, v_loc_cp, 3, 'rm-paneer', -5.4, 'KOT Preparation', 'KOT-82', 295.0)
  ON CONFLICT (row_id) DO NOTHING;

  -- 18. POS Recipes & Lines
  INSERT INTO public.pos_recipes (row_id, organization_id, location_id, id, code, name, version, linked_menu_item_id, linked_menu_item_name, category, portion, target_price, labor_cost, packaging_cost, trial_result, training_done, training_total, status, prep_method, allergens, active_channels)
  VALUES 
    ('cb000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 'rcp_sb_01', 'RCP-SB-BC-01', 'Spicy Butter Chicken', 'v1.4', 'd0000000-0000-0000-0000-000000000001', 'Spicy Butter Chicken', 'North Indian Curry', 'Standard portion (450g)', 380.0, 15.0, 12.0, 'Pass (v1.4)', 5, 5, 'Active', 'Marinate chicken in spiced curd for 4 hrs, char in tandoor, simmer in tomato cashew gravy.', 'Dairy, Cashew Nuts', 'Swiggy, Zomato, Dine-In'),
    ('cb000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 'rcp_sb_02', 'RCP-SB-PBM-02', 'Paneer Butter Masala', 'v1.3', 'd0000000-0000-0000-0000-000000000002', 'Paneer Butter Masala', 'North Indian Curry', 'Standard portion (420g)', 340.0, 10.0, 10.0, 'Pass (v1.3)', 5, 5, 'Active', 'Sauté cottage cheese in butter, fold into creamy spiced makhani gravy.', 'Dairy (Paneer, Butter, Cream)', 'Swiggy, Zomato, Dine-In')
  ON CONFLICT (row_id) DO NOTHING;

  INSERT INTO public.pos_recipe_lines (row_id, organization_id, location_id, id, recipe_id, material_id, name, qty, unit, wastage_pct, fallback_unit_cost, is_key)
  VALUES 
    ('cc000000-0000-0000-0000-000000000001', v_org_id, v_loc_cp, 1, 'rcp_sb_01', 'rm-chicken', 'Raw Chicken Breast', 0.25, 'kg', 4.0, 225.0, true),
    ('cc000000-0000-0000-0000-000000000002', v_org_id, v_loc_cp, 2, 'rcp_sb_01', 'rm-butter', 'Amul Butter Block', 0.04, 'kg', 0.0, 510.0, true),
    ('cc000000-0000-0000-0000-000000000003', v_org_id, v_loc_cp, 3, 'rcp_sb_02', 'rm-paneer', 'Fresh Paneer Block', 0.18, 'kg', 2.0, 295.0, true),
    ('cc000000-0000-0000-0000-000000000004', v_org_id, v_loc_cp, 4, 'rcp_sb_02', 'rm-butter', 'Amul Butter Block', 0.035, 'kg', 0.0, 510.0, true)
  ON CONFLICT (row_id) DO NOTHING;

  -- 19. POS Campaigns & Offers
  INSERT INTO public.pos_offers (row_id, organization_id, location_id, id, title, code, campaign_type, discount_rule, min_order, max_discount, start_date, end_date, channels, linked_items, status, usage_count)
  VALUES 
    ('f0000000-0000-0000-0000-000000000021', v_org_id, v_loc_cp, 'OFF-SB-01', 'Weekend Makhani Fest', 'SPICYFEST25', 'Flat Discount', '25% OFF (Upto ₹100)', 300.0, 100.0, now() - interval '5 days', now() + interval '15 days', 'Dine-In, Zomato, Swiggy', 'Spicy Butter Chicken, Paneer Butter Masala', 'Active', 142),
    ('f0000000-0000-0000-0000-000000000022', v_org_id, v_loc_cp, 'OFF-SB-02', 'Free Garlic Naan Combo', 'NAANFREE', 'BOGO Free', 'Free Garlic Naan on ₹350+', 350.0, 60.0, now() - interval '2 days', now() + interval '20 days', 'Dine-In, Web Portal', 'Garlic Butter Naan', 'Active', 78)
  ON CONFLICT (row_id) DO NOTHING;

  -- 20. POS Media Assets
  INSERT INTO public.pos_media_assets (row_id, organization_id, location_id, id, file_name, file_type, size_bytes, folder, usage_label, image_url, archived)
  VALUES 
    ('e0000000-0000-0000-0000-000000000031', v_org_id, v_loc_cp, 'med_sb_01', 'butter_chicken_hero.png', 'PNG', 2457600, 'Dishes', 'Menu Header & POS Display', 'https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=500', false),
    ('e0000000-0000-0000-0000-000000000032', v_org_id, v_loc_cp, 'med_sb_02', 'spicy_bistro_logo.png', 'PNG', 1153433, 'Branding', 'Brand Logo & Receipt Header', 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500', false)
  ON CONFLICT (row_id) DO NOTHING;

  -- 21. POS Shifts & Cash
  INSERT INTO public.pos_shifts (row_id, organization_id, location_id, shift_id, device_location_id, opening_float_minor, opened_at, closed_at, counted_cash_minor)
  VALUES 
    ('e0000000-0000-0000-0000-000000000041', v_org_id, v_loc_cp, 'SHIFT-20260928-M1', 'POS-TERM-01', 500000, now() - interval '6 hours', NULL, NULL),
    ('e0000000-0000-0000-0000-000000000042', v_org_id, v_loc_cp, 'SHIFT-20260927-E1', 'POS-TERM-01', 500000, now() - interval '24 hours', now() - interval '14 hours', 1845000)
  ON CONFLICT (row_id) DO NOTHING;

  -- 22. POS Deliveries & Riders
  INSERT INTO public.pos_deliveries (row_id, organization_id, location_id, id, order_id, merchant, rider_name, status, eta_minutes, distance_km, customer_name, address, promised_at, created_at, updated_at)
  VALUES 
    ('e0000000-0000-0000-0000-000000000051', v_org_id, v_loc_cp, 'DEL-8801', 'OL-ORD-101', 'Spicy Bistro - Connaught Place', 'Sachin Kamble', 'in_transit', 18, 3.2, 'Arjun Mehta', '12 Shivaji Chowk, Latur', now() + interval '18 minutes', now() - interval '20 minutes', now()),
    ('e0000000-0000-0000-0000-000000000052', v_org_id, v_loc_cp, 'DEL-8802', 'OL-ORD-102', 'Spicy Bistro - Connaught Place', 'Raju Patil', 'assigned', 30, 4.5, 'Kavita Joshi', 'Flat 102, Green Valley, Latur', now() + interval '30 minutes', now() - interval '5 minutes', now())
  ON CONFLICT (row_id) DO NOTHING;

  -- 23. POS Table Reservations
  INSERT INTO public.pos_reservations (row_id, organization_id, location_id, id, guest_name, phone, email, guests, scheduled_at, status, table_id, notes)
  VALUES 
    ('e0000000-0000-0000-0000-000000000061', v_org_id, v_loc_cp, 'RES-2026-001', 'Dr. Alok Verma', '+91 98221 00998', 'alok.verma@aiims.edu', 4, now() + interval '2 hours', 'confirmed', 'T3', 'Anniversary dinner; quiet table requested'),
    ('e0000000-0000-0000-0000-000000000062', v_org_id, v_loc_cp, 'RES-2026-002', 'Megha Kapoor', '+91 97110 33445', 'megha@corp.in', 6, now() + interval '4 hours', 'confirmed', 'T4', 'Window seating preferred')
  ON CONFLICT (row_id) DO NOTHING;

  -- 24. POS QR Codes & Active Sessions
  INSERT INTO public.pos_qr_codes (row_id, organization_id, location_id, table_id, enabled, token, last_scanned_at)
  VALUES 
    ('e0000000-0000-0000-0000-000000000071', v_org_id, v_loc_cp, 'T1', true, 'qr-sb-del-t1', now() - interval '1 hour'),
    ('e0000000-0000-0000-0000-000000000072', v_org_id, v_loc_cp, 'T2', true, 'qr-sb-del-t2', now() - interval '30 minutes')
  ON CONFLICT (row_id) DO NOTHING;

  INSERT INTO public.pos_qr_sessions (row_id, organization_id, location_id, id, table_label, guests, started_at, status, order_id, item_count, total_minor)
  VALUES 
    ('e0000000-0000-0000-0000-000000000081', v_org_id, v_loc_cp, 'QRS-1029', 'T2', 3, now() - interval '45 minutes', 'active', 'f0000000-0000-0000-0000-000000000001', 6, 84000)
  ON CONFLICT (row_id) DO NOTHING;

  -- 25. Franchise Targets, Records & Exceptions
  INSERT INTO public.pos_branch_targets (organization_id, location_id, period_start, period_end, sales_target, orders_target, aov_target, food_cost_target_pct, labour_cost_pct, operating_expense, notes)
  VALUES 
    (v_org_id, v_loc_cp, '2026-09-01', '2026-09-30', 1250000.00, 2400, 520.00, 28.5, 18.0, 210000.00, 'Flagship outlet monthly target'),
    (v_org_id, v_loc_noi, '2026-09-01', '2026-09-30', 850000.00, 1600, 480.00, 30.0, 19.5, 140000.00, 'Noida hub target')
  ON CONFLICT (organization_id, location_id, period_start) DO UPDATE SET sales_target = EXCLUDED.sales_target;

  INSERT INTO public.pos_franchise_records (organization_id, location_id, record_type, title, status, details, created_by_name)
  VALUES 
    (v_org_id, v_loc_cp, 'stock_transfer', 'Stock Transfer: Raw Chicken Breast', 'completed', '{"source_branch":"Noida Warehouse (Sector 62)","target_branch":"Delhi Connaught Place","item":"Raw Chicken Breast","quantity_kg":35.0,"status":"Completed"}'::jsonb, 'Chef Rahul'),
    (v_org_id, v_loc_cp, 'safety_stock_adjustment', 'Safety Stock Adjustment: Fresh Paneer', 'completed', '{"item":"Fresh Paneer Block","previous_threshold_kg":20.0,"new_threshold_kg":40.0,"reason":"High demand on festival promo"}'::jsonb, 'Manager Priya'),
    (v_org_id, v_loc_blr, 'audit_report', 'Quarterly Kitchen Hygiene & FSSAI Audit', 'completed', '{"score":94.5,"rating":"A+","findings":"All temperature logs maintained; storage labeling compliant"}'::jsonb, 'Auditor Sanjeev')
  ON CONFLICT DO NOTHING;

  INSERT INTO public.pos_franchise_exceptions (organization_id, location_id, severity, root_cause, impact, recommended_action, action_type, status, source, dedupe_key)
  VALUES 
    (v_org_id, v_loc_cp, 'warning', 'Alphonso Mango Pulp below safety stock (18 kg vs 25 kg minimum)', 'Risk of 86ing Mango Lassi during weekend rush', 'Initiate emergency purchase order with SPL-0082', 'Reorder', 'open', 'system', 'exc-sb-cp-mango-pulp-20260928'),
    (v_org_id, v_loc_noi, 'info', 'Peak Friday dinner rush table turnaround delayed by 8 mins', 'Average table wait time increased to 22 mins', 'Assign additional runner to Section B', 'Review', 'open', 'manual', 'exc-sb-noi-turnaround-20260928')
  ON CONFLICT (organization_id, dedupe_key) DO UPDATE SET status = 'open';

  RAISE NOTICE 'Spicy Bistro restaurant vendor test data successfully seeded!';
END $$;
