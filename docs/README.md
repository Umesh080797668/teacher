# Eduverse Teacher Panel - Documentation

This folder contains the official documentation for the Eduverse Teacher Panel mobile application.

## 📄 Documents

1. **user_manual.html** - Comprehensive User Manual
   - Complete guide to all features
   - Step-by-step instructions
   - Troubleshooting tips
   - Best practices

2. **user_agreement.html** - Legal User Agreement
   - Terms of service
   - Privacy policy details
   - User rights and obligations
   - Legal disclaimers

## 🖨️ Converting to PDF

You can convert these HTML files to PDF using any of the following methods:

### Method 1: Using a Web Browser (Easiest)
1. Open the HTML file in any web browser (Chrome, Firefox, Edge, Safari)
2. Press `Ctrl+P` (Windows/Linux) or `Cmd+P` (Mac)
3. Select "Save as PDF" as the destination
4. Adjust settings:
   - Enable "Background graphics" for colors and designs
   - Set margins to "Minimum" or "None"
   - Choose page size: A4 or Letter
5. Click "Save" and choose your destination

**Recommended browsers for best results:**
- Google Chrome (best quality)
- Microsoft Edge
- Firefox

### Method 2: Using Online Tools
Visit any of these free online converters:
- https://www.sejda.com/html-to-pdf
- https://cloudconvert.com/html-to-pdf
- https://www.pdf2go.com/html-to-pdf

Upload the HTML file and download the PDF.

### Method 3: Using Command Line Tools

#### wkhtmltopdf (Linux/Mac/Windows)
```bash
# Install wkhtmltopdf first
# Ubuntu/Debian:
sudo apt-get install wkhtmltopdf

# Convert to PDF
wkhtmltopdf user_manual.html user_manual.pdf
wkhtmltopdf user_agreement.html user_agreement.pdf
```

#### Chromium Headless (Linux/Mac/Windows)
```bash
# Install chromium-browser or chrome
# Convert to PDF
chromium-browser --headless --disable-gpu --print-to-pdf=user_manual.pdf user_manual.html
chromium-browser --headless --disable-gpu --print-to-pdf=user_agreement.pdf user_agreement.html
```

### Method 4: Using Python
```python
# Install pdfkit: pip install pdfkit
import pdfkit

pdfkit.from_file('user_manual.html', 'user_manual.pdf')
pdfkit.from_file('user_agreement.html', 'user_agreement.pdf')
```

## 📋 Features of These Documents

### User Manual
- ✅ Professional gradient design
- ✅ Comprehensive table of contents with hyperlinks
- ✅ 13 detailed sections covering all features
- ✅ Step-by-step instructions
- ✅ Visual cards and highlighted boxes
- ✅ Troubleshooting guide
- ✅ Best practices recommendations
- ✅ Support information
- ✅ Print-optimized CSS

### User Agreement
- ✅ Professional legal document design
- ✅ Clearly numbered articles
- ✅ Table of contents for easy navigation
- ✅ 19 comprehensive sections
- ✅ Highlighted important clauses
- ✅ Contact information for all departments
- ✅ Legal terminology and formatting
- ✅ Print-friendly layout

## 🎨 Styling

Both documents feature:
- Modern, professional design
- Gradient backgrounds
- Color-coded sections
- Easy-to-read typography
- Responsive layout
- Print-optimized CSS
- Professional color scheme (purple/blue theme)

## 📱 Compatibility

The HTML files are compatible with:
- All modern web browsers
- Mobile devices (responsive design)
- PDF converters
- Print services

## ✏️ Customization

To customize these documents:

1. Open the HTML file in any text editor
2. Modify content within the `<div class="content">` section
3. Update company information in headers and footers
4. Change colors by modifying CSS gradients
5. Add your logo by replacing placeholder text

### Quick Customization Tips:
- **Colors**: Search for `#667eea` and `#764ba2` to change the primary color scheme
- **Company Name**: Search and replace "Eduverse" with your company name
- **Contact Info**: Update email addresses and contact information
- **Logo**: Add `<img>` tag in the header section

## 📞 Support

For questions about these documents, contact:
- **Email**: support@eduverse.com
- **Website**: www.eduverse.com

---

**Generated**: January 2026
**Version**: 1.0
**App Version**: 1.0.27

© 2026 Eduverse Education Solutions. All rights reserved.
