import Page from "./utility/page";

let SearchTrendsTrack = {};
let Chart = null;

SearchTrendsTrack.initialize = async function () {
  if (!Page.matches("search-trends", "track")) return;

  const canvas = document.getElementById("search-trend-chart");
  if (!canvas) return;

  const tags = canvas.dataset.tags.split(",");
  const response = await fetch(`/search_trends/track.json?tag=${encodeURIComponent(tags.join(","))}`);
  const data = await response.json();

  // Lazy-load Chart.js only when needed (excluded from main bundle)
  if (!Chart) {
    const { Chart: ChartClass, LineController, LineElement, PointElement, CategoryScale, LinearScale, Tooltip } = await import("chart.js");
    ChartClass.register(LineController, LineElement, PointElement, CategoryScale, LinearScale, Tooltip);
    Chart = ChartClass;
  }

  new Chart(canvas, {
    type: "line",
    defaults: {
      backgroundColor: "#1f3c67",
      borderColor: "red",
      borderWidth: 2,
    },
    data: {
      datasets: Object.entries(data).map(([tag, rows], index) => ({
        label: tag,
        data: rows.map(row => ({ x: row.day, y: row.count })),
        backgroundColor: `hsl(${index * 60}, 70%, 50%)`,
        borderColor: `hsl(${index * 60}, 70%, 50%)`,
        spanGaps: true,
      })),
    },
    options: {
      scales: {
        x: { title: { display: true, text: "Day" } },
        y: { beginAtZero: true, title: { display: true, text: "Searches" } },
      },
      plugins: {
        legend: {
          display: true,
          position: "top",
        },
        tooltip: {
          intersect: false,
          mode: "index",
        },
      },
    },
  });
};

$(() => {
  SearchTrendsTrack.initialize();
});

export default SearchTrendsTrack;
