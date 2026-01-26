export const metadata = {
  title: 'Privacy Policy - Keyframe',
  description: 'Privacy policy for the Keyframe storyboard creation tool',
};

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-white py-16 px-4">
      <article className="max-w-2xl mx-auto prose prose-zinc">
        <h1>Privacy Policy</h1>
        <p className="text-zinc-500">Last updated: January 26, 2026</p>
        
        <h2>Introduction</h2>
        <p>
          Keyframe (&ldquo;we,&rdquo; &ldquo;our,&rdquo; or &ldquo;us&rdquo;) respects your privacy. 
          This Privacy Policy explains how we collect, use, and protect your information 
          when you use our storyboard creation service.
        </p>
        
        <h2>Information We Collect</h2>
        <h3>Information You Provide</h3>
        <ul>
          <li><strong>API Keys:</strong> If you use the standalone app, you provide your own OpenAI API key. 
          This key is stored only in your browser&apos;s local storage and is never sent to our servers.</li>
          <li><strong>Content:</strong> Images you upload as style references, character descriptions, 
          and storyboard content are processed by OpenAI&apos;s API directly from your browser.</li>
        </ul>
        
        <h3>Information Collected Automatically</h3>
        <ul>
          <li><strong>Usage Data:</strong> We may collect anonymous usage statistics to improve the service.</li>
          <li><strong>Log Data:</strong> Standard server logs may include IP addresses and request metadata.</li>
        </ul>
        
        <h2>How We Use Your Information</h2>
        <ul>
          <li>To provide the storyboard creation service</li>
          <li>To improve and optimize the user experience</li>
          <li>To respond to support requests</li>
        </ul>
        
        <h2>Data Storage</h2>
        <p>
          <strong>Standalone App:</strong> All data (API keys, storyboard content, images) is stored 
          locally in your browser. We do not have access to this data.
        </p>
        <p>
          <strong>ChatGPT App:</strong> When used as a ChatGPT app, your data is processed through 
          ChatGPT&apos;s infrastructure. Please refer to OpenAI&apos;s privacy policy for details.
        </p>
        
        <h2>Third-Party Services</h2>
        <p>
          Keyframe uses OpenAI&apos;s API for image generation and style analysis. 
          Your content is subject to <a href="https://openai.com/policies/privacy-policy" target="_blank" rel="noopener noreferrer">OpenAI&apos;s Privacy Policy</a>.
        </p>
        
        <h2>Data Security</h2>
        <p>
          We implement reasonable security measures to protect your information. 
          However, no method of transmission over the Internet is 100% secure.
        </p>
        
        <h2>Your Rights</h2>
        <p>You have the right to:</p>
        <ul>
          <li>Access your personal data</li>
          <li>Delete your data (clear browser storage)</li>
          <li>Opt out of analytics (if any)</li>
        </ul>
        
        <h2>Children&apos;s Privacy</h2>
        <p>
          Keyframe is not intended for users under 13 years of age. 
          We do not knowingly collect information from children.
        </p>
        
        <h2>Changes to This Policy</h2>
        <p>
          We may update this Privacy Policy from time to time. 
          We will notify you of any changes by posting the new policy on this page.
        </p>
        
        <h2>Contact Us</h2>
        <p>
          If you have questions about this Privacy Policy, please contact us at{' '}
          <a href="mailto:privacy@keyframe-app.netlify.app">privacy@keyframe-app.netlify.app</a>.
        </p>
      </article>
    </main>
  );
}
