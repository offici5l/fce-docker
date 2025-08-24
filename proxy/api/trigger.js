import fetch from "node-fetch";

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "*");
  res.setHeader("Access-Control-Allow-Headers", "*");

  if (req.method === "OPTIONS") return res.status(200).end();

  const { url, file, unique_id } = req.body;
  if (!url || !file || !unique_id) return res.status(400).json({ ok: false, error: "Missing required fields" });

  try {
    const response = await fetch("https://api.github.com/repos/offici5l/FCE/actions/workflows/fce.yml/dispatches", {
      method: "POST",
      headers: { "Authorization": `Bearer ${process.env.GITHUB_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ ref: "main", inputs: { url, file_to_extract: file, unique_id } })
    });

    if (!response.ok) throw new Error(await response.text());
    res.status(200).json({ ok: true });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}