const express = require('express');
const db      = require('../db');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

// ─── GET /saves — List all slots ──────────────────────────────────────────
router.get('/', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT slot, version, data, data->>'saved_at' as saved_at, data->>'slot_name' as slot_name
       FROM saves WHERE user_id = $1 ORDER BY slot ASC`,
      [req.user.user_id]
    );
    res.json({ success: true, slots: rows });
  } catch (err) { next(err); }
});

// ─── GET /saves/:slot — Load specific slot ────────────────────────────────
router.get('/:slot', requireAuth, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT data FROM saves WHERE user_id = $1 AND slot = $2`,
      [req.user.user_id, req.params.slot]
    );
    if (rows.length === 0) return res.status(404).json({ success: false, error: 'Slot is empty' });
    res.json({ success: true, data: rows[0].data });
  } catch (err) { next(err); }
});

// ─── POST /saves/:slot — Save to slot ─────────────────────────────────────
router.post('/:slot', requireAuth, async (req, res, next) => {
  try {
    const { data } = req.body;
    if (!data) return res.status(400).json({ error: 'data required' });

    await db.query(
      `INSERT INTO saves (user_id, slot, data)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, slot) DO UPDATE SET data = EXCLUDED.data, created_at = NOW()`,
      [req.user.user_id, req.params.slot, data]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

// ─── DELETE /saves/:slot — Delete slot ────────────────────────────────────
router.delete('/:slot', requireAuth, async (req, res, next) => {
  try {
    await db.query(
      `DELETE FROM saves WHERE user_id = $1 AND slot = $2`,
      [req.user.user_id, req.params.slot]
    );
    res.json({ success: true });
  } catch (err) { next(err); }
});

module.exports = router;
