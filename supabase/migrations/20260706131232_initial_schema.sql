CREATE TABLE profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    company_name text NOT NULL,
    first_name text NOT NULL,
    last_name text,
    phone text,
    email text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE contact_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name text NOT NULL,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    UNIQUE(user_id, name)
);

CREATE TABLE contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name text NOT NULL,
    contact_type_id uuid REFERENCES contact_types(id) ON DELETE RESTRICT, 

    phone text,
    email text,
    tax_office text,
    iban text,
    address text,
    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE accounts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name text NOT NULL,
    account_type text NOT NULL CHECK (account_type IN ('cash', 'bank', 'credit_card', 'partner_current')),

    currency text NOT NULL,
    opening_balance numeric(15,2) DEFAULT 0,
    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    name text NOT NULL,
    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE lands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    project_id uuid REFERENCES projects(id) ON DELETE RESTRICT,

    title text NOT NULL,

    city text,
    district text,
    neighborhood text,

    ada text,
    parsel text,
    pafta text,
    tapu_no text,

    area numeric(12,2),

    purchase_price numeric(15,2),
    estimated_value numeric(15,2),

    purchase_date date,

    description text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE land_contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    land_id uuid NOT NULL REFERENCES lands(id) ON DELETE RESTRICT,
    contact_id uuid NOT NULL REFERENCES contacts(id) ON DELETE RESTRICT,

    share_percentage numeric(5,2),

    investment_amount numeric(15,2),
    paid_amount numeric(15,2) DEFAULT 0,
    remaining_amount numeric(15,2) DEFAULT 0,

    notes text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    parent_id uuid REFERENCES categories(id) ON DELETE SET NULL,

    name text NOT NULL,
    type text NOT NULL CHECK (type IN ('income', 'expense')),

    icon text,
    color text,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    transaction_type text NOT NULL CHECK (transaction_type IN ('standard', 'transfer', 'investment_in', 'investment_out')),

    project_id uuid REFERENCES projects(id) ON DELETE RESTRICT,
    land_id uuid REFERENCES lands(id) ON DELETE RESTRICT,
    contact_id uuid REFERENCES contacts(id) ON DELETE RESTRICT,
    account_id uuid REFERENCES accounts(id) ON DELETE RESTRICT,
    category_id uuid REFERENCES categories(id) ON DELETE RESTRICT,
    to_account_id uuid REFERENCES accounts(id) ON DELETE RESTRICT,

    amount numeric(15,2) NOT NULL,

    currency text DEFAULT 'TRY',
    exchange_rate numeric(15,4) DEFAULT 1,

    description text,

    transaction_date timestamptz DEFAULT now(),

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE ledger_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    transaction_id uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    account_id uuid REFERENCES accounts(id) ON DELETE RESTRICT,

    entry_type text NOT NULL CHECK (entry_type IN ('debit', 'credit')),
    amount numeric(15,2) NOT NULL,

    created_at timestamptz DEFAULT now()
);

CREATE TABLE audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    changed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,

    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_at timestamptz DEFAULT now()
);

-- Indexes for foreign keys and common lookup columns
CREATE INDEX ON contacts (user_id);
CREATE INDEX ON contacts (contact_type_id);
CREATE INDEX ON accounts (user_id);
CREATE INDEX ON projects (user_id);
CREATE INDEX ON lands (user_id);
CREATE INDEX ON lands (project_id);
CREATE INDEX ON land_contacts (land_id);
CREATE INDEX ON land_contacts (contact_id);
CREATE INDEX ON categories (user_id);
CREATE INDEX ON categories (parent_id);
CREATE INDEX ON transactions (user_id);
CREATE INDEX ON transactions (project_id);
CREATE INDEX ON transactions (land_id);
CREATE INDEX ON transactions (contact_id);
CREATE INDEX ON transactions (account_id);
CREATE INDEX ON transactions (to_account_id);
CREATE INDEX ON transactions (category_id);
CREATE INDEX ON ledger_entries (transaction_id);
CREATE INDEX ON ledger_entries (account_id);
CREATE INDEX ON audit_log (record_id);