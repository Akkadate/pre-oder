# ระบบรับหิ้วอาหาร - Admin Panel (Operator-First Design)

## ✨ การออกแบบใหม่ตาม Feedback

> **หลักการ**: หน้าเดียว, Mobile-First, ตอบ 5 คำถามภายใน 5 วินาที

### Technology Stack (Simplified)
- **Frontend**: HTML + JavaScript + Supabase SDK
- **Database**: Supabase (PostgreSQL)
- **Backend**: ❌ **ไม่ต้องมี Node.js** - ใช้ Supabase SDK โดยตรง

---

## 🎯 5 คำถามที่หน้า Admin ต้องตอบได้ทันที

1. ✅ **วันนี้ต้องซื้ออะไร กี่กล่อง** → Menu Summary
2. ✅ **ใครสั่งอะไร** → Order List
3. ✅ **ใครยังไม่จ่าย** → Payment Status Icons
4. ✅ **ส่งใครไปแล้วบ้าง** → Delivery Status Icons
5. ✅ **วันนี้กำไรเท่าไร** → Financial Summary

---

## 📊 Database Schema (Revised)

### 1. **rounds** - รอบการรับหิ้ว
```sql
CREATE TABLE rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name text NOT NULL,
  delivery_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('OPEN', 'CLOSED')),
  price_per_box integer NOT NULL DEFAULT 35,
  price_for_three integer NOT NULL DEFAULT 100,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Index for fast lookup
CREATE INDEX idx_rounds_delivery_date ON rounds(delivery_date);
CREATE INDEX idx_rounds_status ON rounds(status);
```

### 2. **orders** - ออเดอร์
```sql
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid REFERENCES rounds(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  department text NOT NULL,
  total_boxes integer NOT NULL,
  total_price integer NOT NULL,
  payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid')),
  delivery_status text NOT NULL DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'delivered')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_orders_round_id ON orders(round_id);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_delivery_status ON orders(delivery_status);
```

### 3. **order_items** - รายการในออเดอร์
```sql
CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  menu_name text NOT NULL,
  quantity integer NOT NULL,
  sell_price integer NOT NULL,      -- ราคาขาย (คำนวณจาก quantity)
  cost_price integer NOT NULL,       -- ต้นทุนที่ต้องซื้อ
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
```

### คำอธิบาย Fields ใหม่:
- **payment_status**: 'pending' (⏳) | 'paid' (💸)
- **delivery_status**: 'pending' (📦) | 'delivered' (✅)
- **sell_price**: ราคาที่เก็บจากลูกค้า
- **cost_price**: ต้นทุนที่ต้องจ่ายร้าน

---

## 🔐 Supabase Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Public: Read current open round
CREATE POLICY "Public can view open rounds"
  ON rounds FOR SELECT
  USING (status = 'OPEN');

-- Public: Insert orders to open rounds
CREATE POLICY "Public can insert orders to open rounds"
  ON orders FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM rounds 
      WHERE rounds.id = round_id 
      AND rounds.status = 'OPEN'
    )
  );

-- Public: Read their own orders
CREATE POLICY "Public can view orders"
  ON orders FOR SELECT
  USING (true);

-- Public: Insert order items
CREATE POLICY "Public can insert order items"
  ON order_items FOR INSERT
  WITH CHECK (true);

-- Public: Read order items
CREATE POLICY "Public can view order items"
  ON order_items FOR SELECT
  USING (true);

-- Admin: Full access (ใช้ service_role key)
```

---

## 📱 Admin Page Structure

### หน้าเดียว: `admin.html`

```
┌──────────────────────────────┐
│ 📦 กุยช่ายบ้านบึง – 6 ม.ค.  │ ← Header
│ สถานะ: OPEN                  │
│ [ปิดรอบ]                     │
├──────────────────────────────┤
│ 🧾 ต้องซื้อวันนี้            │ ← Menu Summary
│ กุยช่ายล้วน    x 6          │
│ เผือกล้วน      x 4          │
│ ─────────────────           │
│ รวม           10 กล่อง       │
├──────────────────────────────┤
│ 👥 รายการออเดอร์ (10)       │ ← Order List
│                              │
│ Akkadate    ⏳📦            │
│ กุยช่าย x2                  │
│ [💸 จ่ายแล้ว] [✅ส่งแล้ว]  │
│ ────────────────            │
│ Somchai     💸✅            │
│ เผือก x1                    │
│ ────────────────            │
├──────────────────────────────┤
│ 💰 สรุปเงิน                  │ ← Financial Summary
│ รายรับ:  350 บาท            │
│ ต้นทุน:  300 บาท            │
│ กำไร:     50 บาท            │
└──────────────────────────────┘
```

---

## 🧩 Features & Functions

### 1. Header Section
```javascript
// ดึงข้อมูล round ปัจจุบัน
const { data: round } = await supabase
  .from('rounds')
  .select('*')
  .eq('delivery_date', today)
  .single();

// ปุ่มปิดรอบ
async function closeRound() {
  await supabase
    .from('rounds')
    .update({ status: 'CLOSED' })
    .eq('id', roundId);
}
```

### 2. Menu Summary (สำคัญสุด!)
```javascript
// Group by menu_name, sum quantity
const { data: menuSummary } = await supabase
  .from('order_items')
  .select(`
    menu_name,
    quantity,
    order:orders!inner(round_id)
  `)
  .eq('order.round_id', roundId);

// Aggregate
const summary = {};
menuSummary.forEach(item => {
  summary[item.menu_name] = (summary[item.menu_name] || 0) + item.quantity;
});
```

### 3. Order List with Realtime
```javascript
// Subscribe to realtime changes
const subscription = supabase
  .channel('orders')
  .on('postgres_changes', 
    { event: '*', schema: 'public', table: 'orders' },
    handleOrderChange
  )
  .subscribe();

// Toggle payment status
async function togglePayment(orderId, currentStatus) {
  const newStatus = currentStatus === 'pending' ? 'paid' : 'pending';
  await supabase
    .from('orders')
    .update({ payment_status: newStatus })
    .eq('id', orderId);
}

// Toggle delivery status
async function toggleDelivery(orderId, currentStatus) {
  const newStatus = currentStatus === 'pending' ? 'delivered' : 'pending';
  await supabase
    .from('orders')
    .update({ delivery_status: newStatus })
    .eq('id', orderId);
}
```

### 4. Financial Summary
```javascript
const { data: financial } = await supabase
  .from('order_items')
  .select(`
    sell_price,
    cost_price,
    order:orders!inner(round_id)
  `)
  .eq('order.round_id', roundId);

const revenue = financial.reduce((sum, item) => sum + item.sell_price, 0);
const cost = financial.reduce((sum, item) => sum + item.cost_price, 0);
const profit = revenue - cost;
```

---

## 🎨 UI/UX Guidelines

### Colors (Status Indicators)
```css
.status-pending-payment { color: #f59e0b; } /* ⏳ Orange */
.status-paid { color: #10b981; }            /* 💸 Green */
.status-pending-delivery { color: #6b7280; } /* 📦 Gray */
.status-delivered { color: #3b82f6; }       /* ✅ Blue */
```

### Typography
```css
.menu-summary-number { font-size: 32px; font-weight: 700; }
.order-name { font-size: 18px; font-weight: 600; }
.financial-number { font-size: 24px; }
```

### Mobile-First Breakpoints
```css
/* หน้าจอเล็ก (iPhone) - ปกติ */
@media (min-width: 768px) {
  /* แท็บเล็ต - ถ้ามี */
}
```

---

## 📝 Customer Page Updates (`index2.html`)

### เพิ่ม Cost Price Calculation
```javascript
function calculateCostPrice(quantity) {
  // สมมติต้นทุน = 80% ของราคาขาย
  const sellPrice = calculatePrice(quantity);
  return Math.floor(sellPrice * 0.8);
}
```

### แก้ไข confirmOrder()
```javascript
async function confirmOrder() {
  // 1. Get current round
  const { data: round } = await supabase
    .from('rounds')
    .select('*')
    .eq('status', 'OPEN')
    .order('delivery_date', { ascending: false })
    .limit(1)
    .single();

  if (!round) {
    Swal.fire('ปิดรับแล้ว', 'ขณะนี้ปิดรับออเดอร์แล้วครับ', 'info');
    return;
  }

  // 2. Create order
  const totalBoxes = orderItems.reduce((sum, item) => sum + item.qty, 0);
  const totalPrice = calculatePrice(totalBoxes);

  const { data: order, error } = await supabase
    .from('orders')
    .insert({
      round_id: round.id,
      customer_name: nameInput.value.trim(),
      department: deptInput.value.trim(),
      total_boxes: totalBoxes,
      total_price: totalPrice
    })
    .select()
    .single();

  // 3. Create order items
  const items = orderItems.map(item => ({
    order_id: order.id,
    menu_name: item.menu,
    quantity: item.qty,
    sell_price: calculatePrice(item.qty),
    cost_price: calculateCostPrice(item.qty)
  }));

  await supabase.from('order_items').insert(items);

  // 4. Show success
  Swal.fire({
    icon: 'success',
    title: 'รับออเดอร์เรียบร้อย!',
    html: `วันส่ง: ${round.delivery_date}...`
  });

  orderItems = [];
  renderSummary();
}
```

---

## 🚀 Implementation Phases (Simplified)

### Phase 1: Supabase Setup (1 hour)
- [x] สร้าง Supabase project
- [ ] Run SQL schema
- [ ] ตั้งค่า RLS policies
- [ ] สร้าง round ทดสอบ

### Phase 2: Update Customer Page (2-3 hours)
- [ ] เพิ่ม Supabase SDK
- [ ] แก้ไข `confirmOrder()` ให้บันทึกลง database
- [ ] เพิ่ม cost price calculation
- [ ] ตรวจสอบ round status ก่อนสั่ง
- [ ] Testing

### Phase 3: Admin Page - Layout (2-3 hours)
- [ ] สร้าง `admin.html` พื้นฐาน
- [ ] Header + Round Info
- [ ] เชื่อม Supabase
- [ ] Mobile-first CSS

### Phase 4: Admin Page - Features (3-4 hours)
- [ ] Menu Summary (realtime)
- [ ] Order List (realtime)
- [ ] Payment/Delivery toggle buttons
- [ ] Financial Summary
- [ ] Close Round button

### Phase 5: Testing & Polish (1-2 hours)
- [ ] Test E2E flow
- [ ] Test realtime updates
- [ ] Mobile testing
- [ ] ปรับแต่ง UX

**Total: 8-12 hours** (ลดลงจาก 17-26!)

---

## 🔑 Supabase SDK Setup

### Installation
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

### Initialization
```javascript
const SUPABASE_URL = 'your-project-url';
const SUPABASE_ANON_KEY = 'your-anon-key';
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

### Environment Variables
```javascript
// config.js (ไม่ commit ลง Git)
const config = {
  supabaseUrl: 'https://xxx.supabase.co',
  supabaseKey: 'eyJxxx...'
};
```

---

## ✅ Success Criteria (ตามที่คุณบอก)

- [ ] คุณเปิดหน้านี้แทน LINE
- [ ] คุณไม่ต้องจดอะไรในกระดาษ
- [ ] คุณรู้ยอดทั้งหมดก่อนกลับโต๊ะ
- [ ] ตอบ 5 คำถามได้ภายใน 5 วินาที

---

## 📦 Deliverables

1. ✅ `index2.html` - Customer page (Done)
2. 🆕 `admin.html` - Operator page (To build)
3. 🆕 `config.js` - Supabase config
4. 🆕 Database schema SQL file
5. 🆕 Sample data SQL

---

## 🎯 Key Differences from Previous Plan

| Before | After |
|--------|-------|
| 5 หน้า admin | **1 หน้าเดียว** |
| Node.js backend | **ไม่ต้องมี - ใช้ Supabase SDK** |
| Complex dashboard | **Simple operator view** |
| Desktop-first | **Mobile-first** |
| 17-26 hours | **8-12 hours** |
| Multi-role admin | **Single operator** |

---

## 💡 Recommendations

### 1. ใช้ Supabase Realtime
เมื่อมี order ใหม่ → หน้า admin อัพเดททันทีโดยไม่ต้อง refresh

### 2. PWA (Progressive Web App)
เพิ่ม manifest.json → "Add to Home Screen" → เหมือน native app

### 3. Offline Support (Optional)
Local Storage cache → ใช้งานได้แม้เน็ตช้า

### 4. Cost Price Configuration
เก็บ `cost_percentage` ใน rounds table → ต้นทุนปรับได้ตามรอบ

---

## 🚦 Next Steps

1. ✅ Review & approve แผนนี้
2. Setup Supabase project
3. สร้าง database schema
4. Update customer page
5. Build admin page
6. Test & deploy

พร้อมเริ่มทำเลยครับ! 🎉
