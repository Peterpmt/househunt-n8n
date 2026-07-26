-- ============================================================
-- 1. ENABLE PGVector (AI Semantic Search)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- 2. USERS (Unified across all channels)
-- ============================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(20) UNIQUE,
    facebook_id VARCHAR(100) UNIQUE,
    tiktok_id VARCHAR(100) UNIQUE,
    email VARCHAR(255),
    name VARCHAR(255),
    user_type VARCHAR(20) DEFAULT 'unknown' CHECK (user_type IN ('tenant', 'landlord', 'agent', 'developer', 'unknown')),
    default_currency VARCHAR(10) DEFAULT 'KES',
    language VARCHAR(10) DEFAULT 'en',
    mpesa_phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE,
    preferences JSONB DEFAULT '{}'::jsonb
);

-- ============================================================
-- 3. LISTINGS (RENT + SALE + ALL PROPERTY TYPES)
-- ============================================================
CREATE TABLE listings (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    source VARCHAR(20) DEFAULT 'website' CHECK (source IN ('website', 'whatsapp', 'facebook', 'tiktok', 'scraped')),
    
    -- Rent or Sale
    transaction_type VARCHAR(10) DEFAULT 'rent' CHECK (transaction_type IN ('rent', 'sale')),
    
    -- All property types
    property_type VARCHAR(30) CHECK (property_type IN ('house', 'office', 'godown', 'room', 'airbnb', 'shop', 'land')),
    title VARCHAR(255),
    description TEXT,
    
    -- Price (monthly for rent, total for sale)
    price DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'KES',
    
    location_text TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    area_sqft INTEGER,
    bedrooms SMALLINT,
    bathrooms SMALLINT,
    amenities TEXT[] DEFAULT '{}',
    images TEXT[] DEFAULT '{}',
    video_url TEXT,
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'rented', 'sold', 'pending', 'hidden')),
    
    -- Dynamic commission (e.g., 5.00 for 5%, 3.00 for 3%)
    commission_rate DECIMAL(5,2) DEFAULT NULL,
    
    is_boosted BOOLEAN DEFAULT FALSE,
    boost_expires_at TIMESTAMP WITH TIME ZONE,
    view_count INTEGER DEFAULT 0,
    inquiry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    embedding VECTOR(768)
);

-- ============================================================
-- 4. BOOKINGS / ENQUIRIES (RENT + SALE)
-- ============================================================
CREATE TABLE bookings (
    id SERIAL PRIMARY KEY,
    listing_id INTEGER REFERENCES listings(id) ON DELETE CASCADE,
    tenant_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    landlord_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'enquiry' CHECK (status IN ('enquiry', 'pending', 'confirmed', 'cancelled', 'completed', 'no_show')),
    viewing_slot TIMESTAMP WITH TIME ZONE,
    duration_minutes SMALLINT DEFAULT 30,
    tenant_message TEXT,
    landlord_feedback TEXT,
    booking_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    price_at_booking DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'KES',
    
    -- Commission fields frozen from listing
    commission_rate DECIMAL(5,2) DEFAULT NULL,
    commission DECIMAL(12,2) DEFAULT 0,
    commission_currency VARCHAR(10) DEFAULT 'KES',
    commission_paid BOOLEAN DEFAULT FALSE,
    
    source VARCHAR(20) DEFAULT 'website' CHECK (source IN ('website', 'whatsapp', 'facebook', 'tiktok'))
);

-- ============================================================
-- 5. INVOICES (Billing Engine)
-- ============================================================
CREATE TABLE invoices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    booking_id INTEGER REFERENCES bookings(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    amount DECIMAL(12,2),
    currency VARCHAR(10) DEFAULT 'KES',
    status VARCHAR(20) DEFAULT 'issued' CHECK (status IN ('issued', 'paid', 'overdue', 'cancelled')),
    issue_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    due_date TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '7 days',
    paid_date TIMESTAMP WITH TIME ZONE,
    payment_method VARCHAR(20),
    payment_reference VARCHAR(255),
    payment_link TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 6. PAYMENT TRANSACTIONS (M-PESA / VISA Callbacks)
-- ============================================================
CREATE TABLE payment_transactions (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER REFERENCES invoices(id) ON DELETE CASCADE,
    amount DECIMAL(12,2),
    currency VARCHAR(10),
    provider VARCHAR(20) CHECK (provider IN ('mpesa', 'visa', 'pesapal', 'stripe')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed')),
    transaction_id VARCHAR(255) UNIQUE,
    callback_payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 7. CONVERSATIONS (Full Chat Memory)
-- ============================================================
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR(100) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('user', 'assistant', 'system')),
    message TEXT,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'interactive', 'form_submission', 'button_click')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 8. FORM SUBMISSIONS (Structured Data)
-- ============================================================
CREATE TABLE form_submissions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    form_type VARCHAR(20) CHECK (form_type IN ('enquiry', 'listing', 'booking')),
    source VARCHAR(20) CHECK (source IN ('website', 'whatsapp', 'facebook', 'tiktok')),
    raw_data JSONB,
    parsed_data JSONB,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================
-- 9. NOTIFICATION QUEUE (PostgreSQL Job Queue)
-- ============================================================
CREATE TABLE notification_queue (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(20) CHECK (channel IN ('whatsapp', 'messenger', 'tiktok', 'email')),
    recipient VARCHAR(255) NOT NULL,
    template_name VARCHAR(50),
    content TEXT,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
    retry_count SMALLINT DEFAULT 0,
    scheduled_for TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT
);

-- ============================================================
-- 10. ANALYTICS EVENTS
-- ============================================================
CREATE TABLE analytics_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50),
    user_id INTEGER REFERENCES users(id),
    listing_id INTEGER REFERENCES listings(id),
    session_id VARCHAR(100),
    payload JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- 11. CRITICAL PERFORMANCE INDEXES
-- ============================================================
CREATE INDEX idx_listings_embedding ON listings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_listings_type_status ON listings(transaction_type, status, currency, price);
CREATE INDEX idx_listings_location ON listings(latitude, longitude);
CREATE INDEX idx_bookings_tenant_status ON bookings(tenant_id, status);
CREATE INDEX idx_invoices_user_status ON invoices(user_id, status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date) WHERE status = 'issued';
CREATE INDEX idx_payment_transactions_invoice ON payment_transactions(invoice_id);
CREATE INDEX idx_notification_queue_pending ON notification_queue(status, scheduled_for) WHERE status = 'pending';
CREATE INDEX idx_conversations_user_session ON conversations(user_id, session_id);

-- ============================================================
-- 12. AUTO-UPDATE TIMESTAMPS (Triggers)
-- ============================================================
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ language 'plpgsql';

CREATE TRIGGER update_listings_timestamp BEFORE UPDATE ON listings FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_invoices_timestamp BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_timestamp();
CREATE TRIGGER update_payments_timestamp BEFORE UPDATE ON payment_transactions FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================
-- 13. TRIGGER: Auto-set Commission Rate based on Transaction Type
-- ============================================================
CREATE OR REPLACE FUNCTION set_default_commission()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.commission_rate IS NULL THEN
        IF NEW.transaction_type = 'sale' THEN
            NEW.commission_rate := 3.00; -- 3% for sale
        ELSE
            NEW.commission_rate := 5.00; -- 5% for rent (of monthly rent)
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_listing_commission
BEFORE INSERT ON listings
FOR EACH ROW EXECUTE FUNCTION set_default_commission();

-- ============================================================
-- 14. HELPER: Upsert User from Channel
-- ============================================================
CREATE OR REPLACE FUNCTION upsert_user_from_channel(
    p_phone VARCHAR,
    p_fb_id VARCHAR,
    p_tt_id VARCHAR,
    p_email VARCHAR,
    p_name VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    INSERT INTO users (phone, facebook_id, tiktok_id, email, name, last_active)
    VALUES (p_phone, p_fb_id, p_tt_id, p_email, p_name, NOW())
    ON CONFLICT (phone) DO UPDATE 
    SET last_active = NOW(), 
        name = EXCLUDED.name,
        facebook_id = COALESCE(users.facebook_id, EXCLUDED.facebook_id),
        tiktok_id = COALESCE(users.tiktok_id, EXCLUDED.tiktok_id)
    RETURNING id INTO v_user_id;
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;
