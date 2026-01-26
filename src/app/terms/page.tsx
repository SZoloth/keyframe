export const metadata = {
  title: 'Terms of Service - Keyframe',
  description: 'Terms of service for the Keyframe storyboard creation tool',
};

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-white py-16 px-4">
      <article className="max-w-2xl mx-auto prose prose-zinc">
        <h1>Terms of Service</h1>
        <p className="text-zinc-500">Last updated: January 26, 2026</p>
        
        <h2>1. Acceptance of Terms</h2>
        <p>
          By accessing or using Keyframe (&ldquo;the Service&rdquo;), you agree to be bound by these 
          Terms of Service. If you do not agree, please do not use the Service.
        </p>
        
        <h2>2. Description of Service</h2>
        <p>
          Keyframe is a storyboard creation tool that uses AI to help users create 
          visual narratives for pitches, presentations, and concepts. The Service 
          is provided &ldquo;as is&rdquo; without warranty of any kind.
        </p>
        
        <h2>3. User Responsibilities</h2>
        <h3>3.1 API Keys</h3>
        <p>
          When using the standalone app, you are responsible for your own OpenAI API key. 
          You are solely responsible for any charges incurred through your API usage.
        </p>
        
        <h3>3.2 Content</h3>
        <p>You agree not to use the Service to:</p>
        <ul>
          <li>Create content that is illegal, harmful, or violates third-party rights</li>
          <li>Generate content that violates OpenAI&apos;s usage policies</li>
          <li>Impersonate others or create misleading content</li>
          <li>Attempt to circumvent any limitations or security measures</li>
        </ul>
        
        <h3>3.3 Ownership</h3>
        <p>
          You retain ownership of the content you create using Keyframe. 
          However, AI-generated content may be subject to OpenAI&apos;s terms regarding 
          generated content.
        </p>
        
        <h2>4. Intellectual Property</h2>
        <p>
          The Keyframe application, including its design, code, and branding, 
          is open source under the MIT License. You may use, modify, and distribute 
          the code according to the license terms.
        </p>
        
        <h2>5. Disclaimer of Warranties</h2>
        <p>
          THE SERVICE IS PROVIDED &ldquo;AS IS&rdquo; AND &ldquo;AS AVAILABLE&rdquo; WITHOUT WARRANTIES 
          OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO:
        </p>
        <ul>
          <li>Warranties of merchantability or fitness for a particular purpose</li>
          <li>Warranties that the service will be uninterrupted or error-free</li>
          <li>Warranties regarding the accuracy of AI-generated content</li>
        </ul>
        
        <h2>6. Limitation of Liability</h2>
        <p>
          TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY 
          INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, 
          INCLUDING BUT NOT LIMITED TO LOSS OF PROFITS, DATA, OR GOODWILL.
        </p>
        
        <h2>7. Third-Party Services</h2>
        <p>
          Keyframe integrates with OpenAI&apos;s services. Your use of these services 
          is subject to their respective terms of service and privacy policies.
        </p>
        
        <h2>8. Modifications to Service</h2>
        <p>
          We reserve the right to modify, suspend, or discontinue the Service 
          at any time without notice. We shall not be liable to you or any third 
          party for any modification, suspension, or discontinuation.
        </p>
        
        <h2>9. Changes to Terms</h2>
        <p>
          We may update these Terms from time to time. Continued use of the Service 
          after changes constitutes acceptance of the new Terms.
        </p>
        
        <h2>10. Governing Law</h2>
        <p>
          These Terms shall be governed by the laws of the State of Colorado, 
          United States, without regard to its conflict of law provisions.
        </p>
        
        <h2>11. Contact</h2>
        <p>
          For questions about these Terms, please contact us at{' '}
          <a href="mailto:legal@keyframe-app.netlify.app">legal@keyframe-app.netlify.app</a>.
        </p>
      </article>
    </main>
  );
}
