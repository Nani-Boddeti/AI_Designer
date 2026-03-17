export type FieldType = 'text' | 'select' | 'boolean' | 'datetime' | 'date' | 'number' | 'readonly';

export interface FieldDef {
  key: string;
  label: string;
  type: FieldType;
  options?: string[];
  editable: boolean;
}

export interface EntityDef {
  key: string;
  label: string;
  table: string;
  listColumns: string[];
  searchColumn: string;
  orderBy: string;
  fields: FieldDef[];
  readOnly?: boolean;
}

export const ENTITIES: EntityDef[] = [
  {
    key: 'households',
    label: 'Households',
    table: 'households',
    listColumns: ['id', 'name', 'tier', 'dynamic_pricing', 'hemisphere', 'created_at'],
    searchColumn: 'name',
    orderBy: 'created_at',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'name', label: 'Name', type: 'text', editable: true },
      { key: 'invite_code', label: 'Invite Code', type: 'readonly', editable: false },
      { key: 'hemisphere', label: 'Hemisphere', type: 'select', options: ['north', 'south'], editable: true },
      { key: 'tier', label: 'Tier', type: 'select', options: ['free', 'pro', 'prime'], editable: true },
      { key: 'tier_expires_at', label: 'Tier Expires At', type: 'datetime', editable: true },
      { key: 'dynamic_pricing', label: 'Dynamic Pricing', type: 'boolean', editable: true },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'profiles',
    label: 'Profiles',
    table: 'profiles',
    listColumns: ['id', 'name', 'household_id', 'age_group', 'gender', 'is_admin'],
    searchColumn: 'name',
    orderBy: 'created_at',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'name', label: 'Name', type: 'text', editable: true },
      { key: 'household_id', label: 'Household ID', type: 'readonly', editable: false },
      { key: 'auth_user_id', label: 'Auth User ID', type: 'readonly', editable: false },
      { key: 'age_group', label: 'Age Group', type: 'select', options: ['toddler', 'child', 'teen', 'adult'], editable: true },
      { key: 'gender', label: 'Gender', type: 'select', options: ['male', 'female', 'other'], editable: true },
      { key: 'skin_tone', label: 'Skin Tone', type: 'select', options: ['fair', 'light', 'medium', 'olive', 'brown', 'dark'], editable: true },
      { key: 'is_admin', label: 'Is Admin', type: 'boolean', editable: true },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'wardrobe-items',
    label: 'Wardrobe Items',
    table: 'wardrobe_items',
    listColumns: ['id', 'name', 'profile_id', 'category', 'subcategory', 'is_private'],
    searchColumn: 'name',
    orderBy: 'created_at',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'name', label: 'Name', type: 'text', editable: true },
      { key: 'profile_id', label: 'Profile ID', type: 'readonly', editable: false },
      { key: 'category', label: 'Category', type: 'select', options: ['top', 'bottom', 'dress', 'outerwear', 'shoes', 'accessory', 'fullSet', 'swimwear'], editable: true },
      { key: 'subcategory', label: 'Subcategory', type: 'text', editable: true },
      { key: 'is_private', label: 'Is Private', type: 'boolean', editable: true },
      { key: 'brand', label: 'Brand', type: 'text', editable: true },
      { key: 'size', label: 'Size', type: 'text', editable: true },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'outfits',
    label: 'Outfits',
    table: 'outfits',
    listColumns: ['id', 'name', 'profile_id', 'occasion', 'harmony_score', 'is_ai_generated'],
    searchColumn: 'name',
    orderBy: 'created_at',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'name', label: 'Name', type: 'text', editable: true },
      { key: 'profile_id', label: 'Profile ID', type: 'readonly', editable: false },
      { key: 'occasion', label: 'Occasion', type: 'text', editable: true },
      { key: 'notes', label: 'Notes', type: 'text', editable: true },
      { key: 'is_ai_generated', label: 'AI Generated', type: 'readonly', editable: false },
      { key: 'harmony_score', label: 'Harmony Score', type: 'readonly', editable: false },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'calendar-events',
    label: 'Calendar Events',
    table: 'calendar_events',
    listColumns: ['id', 'title', 'household_id', 'event_date', 'occasion'],
    searchColumn: 'title',
    orderBy: 'event_date',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'title', label: 'Title', type: 'text', editable: true },
      { key: 'household_id', label: 'Household ID', type: 'readonly', editable: false },
      { key: 'event_date', label: 'Event Date', type: 'date', editable: true },
      { key: 'occasion', label: 'Occasion', type: 'text', editable: true },
      { key: 'notes', label: 'Notes', type: 'text', editable: true },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'app-config',
    label: 'App Config',
    table: 'app_config',
    listColumns: ['id', 'min_version', 'store_url'],
    searchColumn: 'id',
    orderBy: 'id',
    fields: [
      { key: 'id', label: 'ID', type: 'readonly', editable: false },
      { key: 'min_version', label: 'Min Version', type: 'text', editable: true },
      { key: 'store_url', label: 'Store URL', type: 'text', editable: true },
    ],
  },
  {
    key: 'usage',
    label: 'Usage',
    table: 'household_usage',
    listColumns: ['household_id', 'year_month'],
    searchColumn: 'household_id',
    orderBy: 'year_month',
    readOnly: true,
    fields: [
      { key: 'household_id', label: 'Household ID', type: 'readonly', editable: false },
      { key: 'year_month', label: 'Year Month', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'payment-transactions',
    label: 'Payment Transactions',
    table: 'payment_transactions_view',
    listColumns: ['household_name', 'user_name', 'tier', 'amount_paise', 'expires_at', 'created_at'],
    searchColumn: 'household_name',
    orderBy: 'created_at',
    readOnly: true,
    fields: [
      { key: 'id', label: 'Transaction ID', type: 'readonly', editable: false },
      { key: 'household_name', label: 'Household', type: 'readonly', editable: false },
      { key: 'household_id', label: 'Household ID', type: 'readonly', editable: false },
      { key: 'user_name', label: 'Paid By', type: 'readonly', editable: false },
      { key: 'user_id', label: 'User ID', type: 'readonly', editable: false },
      { key: 'tier', label: 'Tier', type: 'readonly', editable: false },
      { key: 'amount_paise', label: 'Amount (paise)', type: 'readonly', editable: false },
      { key: 'razorpay_order_id', label: 'Razorpay Order ID', type: 'readonly', editable: false },
      { key: 'razorpay_payment_id', label: 'Razorpay Payment ID', type: 'readonly', editable: false },
      { key: 'expires_at', label: 'Expires At', type: 'readonly', editable: false },
      { key: 'created_at', label: 'Created At', type: 'readonly', editable: false },
    ],
  },
  {
    key: 'device-tokens',
    label: 'Device Tokens',
    table: 'device_tokens',
    listColumns: ['user_id', 'platform', 'token'],
    searchColumn: 'user_id',
    orderBy: 'user_id',
    readOnly: true,
    fields: [
      { key: 'user_id', label: 'User ID', type: 'readonly', editable: false },
      { key: 'platform', label: 'Platform', type: 'readonly', editable: false },
      { key: 'token', label: 'Token', type: 'readonly', editable: false },
    ],
  },
];

export function getEntity(key: string): EntityDef | undefined {
  return ENTITIES.find((e) => e.key === key);
}
