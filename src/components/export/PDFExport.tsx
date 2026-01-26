'use client';

import { Document, Page, Text, View, Image, StyleSheet, pdf } from '@react-pdf/renderer';
import { StoryboardFrame } from '@/lib/types';

const styles = StyleSheet.create({
  page: {
    padding: 40,
    backgroundColor: '#ffffff',
  },
  titlePage: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  subtitle: {
    fontSize: 14,
    color: '#666666',
  },
  framesPage: {
    padding: 40,
  },
  frameRow: {
    flexDirection: 'row',
    marginBottom: 30,
  },
  frameContainer: {
    flex: 1,
    marginHorizontal: 10,
  },
  frameImage: {
    width: '100%',
    height: 180,
    backgroundColor: '#f4f4f5',
    objectFit: 'contain',
  },
  framePlaceholder: {
    width: '100%',
    height: 180,
    backgroundColor: '#f4f4f5',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    fontSize: 24,
    color: '#a1a1aa',
  },
  frameNumber: {
    fontSize: 10,
    color: '#71717a',
    marginTop: 8,
  },
  frameCaption: {
    fontSize: 12,
    marginTop: 4,
  },
  beatTitle: {
    fontSize: 10,
    color: '#71717a',
    marginTop: 2,
  },
});

interface StoryboardPDFProps {
  projectName: string;
  templateName: string;
  frames: StoryboardFrame[];
}

function StoryboardPDF({ projectName, templateName, frames }: StoryboardPDFProps) {
  // Group frames into pairs for 2-per-page layout
  const framePairs: StoryboardFrame[][] = [];
  for (let i = 0; i < frames.length; i += 2) {
    framePairs.push(frames.slice(i, i + 2));
  }
  
  return (
    <Document>
      {/* Title page */}
      <Page size="A4" style={styles.page}>
        <View style={styles.titlePage}>
          <Text style={styles.title}>{projectName || 'Storyboard'}</Text>
          <Text style={styles.subtitle}>{templateName}</Text>
          <Text style={styles.subtitle}>
            {frames.length} frames • Created with Keyframe
          </Text>
        </View>
      </Page>
      
      {/* Frame pages */}
      {framePairs.map((pair, pageIndex) => (
        <Page key={pageIndex} size="A4" style={styles.framesPage}>
          {pair.map((frame, frameIndex) => {
            const globalIndex = pageIndex * 2 + frameIndex;
            return (
              <View key={frame.id} style={styles.frameRow}>
                <View style={styles.frameContainer}>
                  {frame.imageUrl ? (
                    <Image src={frame.imageUrl} style={styles.frameImage} />
                  ) : (
                    <View style={styles.framePlaceholder}>
                      <Text style={styles.placeholderText}>{globalIndex + 1}</Text>
                    </View>
                  )}
                  <Text style={styles.frameNumber}>Frame {globalIndex + 1}</Text>
                  <Text style={styles.frameCaption}>{frame.caption}</Text>
                  <Text style={styles.beatTitle}>{frame.beatTitle}</Text>
                </View>
              </View>
            );
          })}
        </Page>
      ))}
    </Document>
  );
}

export async function generatePDF(
  projectName: string,
  templateName: string,
  frames: StoryboardFrame[]
): Promise<Blob> {
  const doc = <StoryboardPDF projectName={projectName} templateName={templateName} frames={frames} />;
  const blob = await pdf(doc).toBlob();
  return blob;
}

export function downloadPDF(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}
