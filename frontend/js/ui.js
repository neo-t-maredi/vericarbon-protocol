const byId = (id) => document.getElementById(id);
const statusNames = ["Pending", "Approved", "Rejected", "Active", "Suspended"];

function textElement(tag, value) {
    const element = document.createElement(tag);
    element.textContent = value;
    return element;
}

function message(id, text, error = false) {
    const element = byId(id);
    element.textContent = text;
    element.dataset.error = String(error);
}

function projectCard(project) {
    const card = document.createElement("article");
    card.className = "project";
    const status = statusNames[project.status] ?? "Unknown";
    card.append(
        textElement("small", "Project #" + project.projectId + " · " + status),
        textElement("h3", project.projectName),
        textElement("p", project.location),
        textElement("p", project.description),
        textElement("p", "Applicant estimate: " + project.estimatedAnnualCredits + " tCO₂e per year"),
        textElement("small", "Applicant: " + project.projectOwner)
    );
    return card;
}

function renderContractLinks() {
    for (const [name, address] of Object.entries(CONFIG.CONTRACTS)) {
        const row = document.createElement("div");
        const value = document.createElement("dd");
        const link = textElement("a", address);
        link.href = CONFIG.NETWORK.blockExplorer + "/address/" + address;
        value.append(link);
        row.append(textElement("dt", name), value);
        byId("contractLinks").append(row);
    }
}
