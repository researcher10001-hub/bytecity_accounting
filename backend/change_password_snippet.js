// --- CHANGE PASSWORD ---
function changePassword(e) {
    try {
        const data = JSON.parse(e.postData.contents);
        const email = data.email;
        const newPassword = data.newPassword;

        if (!email || !newPassword) return errorResponse("Missing fields");

        const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_USERS);
        if (!sheet) return errorResponse("Users sheet not found");

        const rows = sheet.getDataRange().getValues();
        let userFound = false;

        for (let i = 1; i < rows.length; i++) {
            if (rows[i][1].toString().toLowerCase() === email.toLowerCase()) {
                // Update Password Hash (Col 3, Index 2)
                const newHash = generateHash(email, newPassword);
                sheet.getRange(i + 1, 3).setValue(newHash);
                userFound = true;
                break;
            }
        }

        if (userFound) {
            return successResponse({ 'message': 'Password updated successfully' });
        } else {
            return errorResponse("User not found");
        }

    } catch (err) {
        return errorResponse("Server error: " + err.toString());
    }
}
