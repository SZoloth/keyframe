import { Template } from './types';

export const templates: Template[] = [
  {
    id: 'raskin-pitch',
    name: 'Raskin Pitch',
    description: 'Andy Raskin\'s 5-part pitch structure. Perfect for product demos and investor presentations.',
    frames: [
      {
        id: 'raskin-1',
        title: 'The Old World',
        guidance: 'Show the status quo. Someone doing things the hard way, before your solution exists.',
      },
      {
        id: 'raskin-2',
        title: 'The Shift',
        guidance: 'External change disrupting the old way. A new reality that demands adaptation.',
      },
      {
        id: 'raskin-3',
        title: 'Winners & Losers',
        guidance: 'Contrast those adapting vs. those stuck. Create urgency through stakes.',
      },
      {
        id: 'raskin-4',
        title: 'The Promised Land',
        guidance: 'Your solution in action. Show relief, success, the new way working.',
      },
      {
        id: 'raskin-5',
        title: 'Proof',
        guidance: 'Evidence it works. Metrics, testimonial, concrete outcome.',
      },
    ],
  },
  {
    id: 'hero-journey',
    name: 'Hero\'s Journey',
    description: 'The classic 8-stage narrative arc. Great for customer stories and case studies.',
    frames: [
      {
        id: 'hero-1',
        title: 'Ordinary World',
        guidance: 'The hero in their normal context before the adventure begins.',
      },
      {
        id: 'hero-2',
        title: 'Call to Adventure',
        guidance: 'The problem appears. Something disrupts the ordinary world.',
      },
      {
        id: 'hero-3',
        title: 'Refusal',
        guidance: 'Hesitation, obstacles, reasons not to act. The resistance.',
      },
      {
        id: 'hero-4',
        title: 'Meeting the Mentor',
        guidance: 'A guide or tool is introduced. Help arrives.',
      },
      {
        id: 'hero-5',
        title: 'Crossing the Threshold',
        guidance: 'Commitment to change. The hero takes action.',
      },
      {
        id: 'hero-6',
        title: 'Tests & Allies',
        guidance: 'Challenges faced along the way. Learning and growth.',
      },
      {
        id: 'hero-7',
        title: 'Ordeal',
        guidance: 'The climactic struggle. The biggest challenge.',
      },
      {
        id: 'hero-8',
        title: 'Return with Elixir',
        guidance: 'Transformed state. The hero returns to a new normal.',
      },
    ],
  },
  {
    id: 'problem-solution',
    name: 'Problem → Solution',
    description: 'Simple 3-frame structure. Quick and effective for demos.',
    frames: [
      {
        id: 'ps-1',
        title: 'Before',
        guidance: 'The frustration, the pain point, the struggle.',
      },
      {
        id: 'ps-2',
        title: 'During',
        guidance: 'Your solution in action. The moment of using it.',
      },
      {
        id: 'ps-3',
        title: 'After',
        guidance: 'The outcome. Relief, success, satisfaction.',
      },
    ],
  },
];

export function getTemplateById(id: string): Template | undefined {
  return templates.find(t => t.id === id);
}
