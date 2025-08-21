import fetch from "node-fetch";

const GITHUB_TOKEN = process.env.GITHUB_TOKEN; 
const REPO = "offici5l/FCE";
const WORKFLOW_FILE = "fce.yml";
const BRANCH = "main";

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { url, file, unique_id } = req.body;

  if (!url || !file || !unique_id) {
    res.status(400).json({ error: "Missing required fields: url, file, unique_id" });
    return;
  }

  try {
    const response = await fetch(
      `https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches`,
      {
        method: "POST",
        headers: {
          "Accept": "application/vnd.github+json",
          "Authorization": `Bearer ${GITHUB_TOKEN}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          ref: BRANCH,
          inputs: { url, file_to_extract: file, unique_id }
        })
      }
    );

    if (!response.ok) {
      const text = await response.text();
      res.status(response.status).json({ error: text });
      return;
    }

    res.status(200).json({ message: "Workflow triggered successfully" });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}