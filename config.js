// Supabase Configuration
// ใส่ค่าจาก Supabase Project Settings > API

const SUPABASE_CONFIG = {
    url: 'https://wawbhunfmbiiudrfuckx.supabase.co',
    key: 'sb_publishable_mMhLpqQzioFhpiIHDPTPwQ_y-dHLQ-7'
};

// Initialize Supabase client if SDK is loaded
const initSupabase = () => {
    if (typeof supabase !== 'undefined') {
        return supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.key);
    }
    console.error('Supabase SDK not loaded');
    return null;
};
