import { useState } from 'react'
import './App.css'
import LoginButton from './LoginButton'
import { apiFetch } from './apiFetch'
import WeatherCard, { type WeatherForecast } from './WeatherCard'

function App() {
  const [weather, setWeather] = useState<WeatherForecast[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  const fetchWeather = async () => {
    console.log("Fetching weather...");
    setError(null)
    try {
      const res = await apiFetch('/weatherforecast')
      console.log(res);
      if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
      setWeather(await res.json())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    }
  }

  return (
    <>
      <section id="center">
        <LoginButton />
        <div>
          <h1>Lets Get the Weather</h1>
        </div>
          <button onClick={fetchWeather}>
            Fetch Weather
          </button>
        {error && <p style={{ color: 'red' }}>{error}</p>}
        {weather && (
          <div className="weather-list">
            {weather.map((w) => (
              <WeatherCard key={w.date} {...w} />
            ))}
          </div>
        )}
      </section>
    </>
  )
}

export default App
