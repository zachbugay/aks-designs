export interface WeatherForecast {
  date: string;
  temperatureC: number;
  temperatureF: number;
  summary: string;
}

export default function WeatherCard({ date, temperatureC, temperatureF, summary }: WeatherForecast) {
  return (
    <div className="weather-card">
      <span className="weather-date">{new Date(date).toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}</span>
      <span className="weather-summary">{summary}</span>
      <div className="weather-temps">
        <span className="weather-temp">{temperatureC}°C</span>
        <span className="weather-divider">/</span>
        <span className="weather-temp">{temperatureF}°F</span>
      </div>
    </div>
  );
}
